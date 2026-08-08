import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import '../middleware/auth_middleware.dart';
import '../realtime/realtime_hub.dart';
import '../utils/json_response.dart';
import '../utils/kst_time.dart';
import '../utils/serialize.dart';

Map<String, dynamic> _serializeKnock(Row row) {
  return {
    'id': row['id'],
    'roomId': row['room_id'],
    'roomName': row['room_name'],
    'requesterId': row['requester_id'],
    'requesterName': row['requester_name'],
    'status': row['status'],
    'createdAt': row['created_at'],
    'respondedAt': row['responded_at'],
  };
}

/// backend/src/routes/rooms.js를 그대로 포팅한 라우터.
/// FCM 푸시(sendPush)는 아직 이식하지 않았다 — 실시간 소켓 알림은 그대로 동작한다.
Router buildRoomsRouter(Database db, String jwtSecret, RealtimeHub hub) {
  final router = Router();

  router.get('/', withAuth(db, jwtSecret, (request, user) {
    final rooms = db.select('SELECT * FROM rooms ORDER BY id').map(publicRoom).toList();
    return jsonResponse({'rooms': rooms});
  }));

  router.post('/', withAuth(db, jwtSecret, (request, user) async {
    final adminError = requireAdmin(user);
    if (adminError != null) return adminError;

    final body = await readJsonBody(request);
    final name = body['name']?.toString().trim();
    if (name == null || name.isEmpty) return jsonError('방 이름을 입력해주세요.');

    db.execute('INSERT INTO rooms (name, access_status, created_at) VALUES (?, ?, ?)', [name, 'open', ServerTime.nowIso()]);
    final room = db.select('SELECT * FROM rooms WHERE id = ?', [db.lastInsertRowId]).first;
    hub.broadcastRooms();
    return jsonResponse({'room': publicRoom(room)}, status: 201);
  }));

  router.patch('/<id>/name', withAuth(db, jwtSecret, (request, user) async {
    final adminError = requireAdmin(user);
    if (adminError != null) return adminError;

    final id = request.params['id'];
    final rows = db.select('SELECT * FROM rooms WHERE id = ?', [id]);
    if (rows.isEmpty) return jsonError('방을 찾을 수 없습니다.', status: 404);

    final body = await readJsonBody(request);
    final name = body['name']?.toString().trim();
    if (name == null || name.isEmpty) return jsonError('방 이름을 입력해주세요.');

    db.execute('UPDATE rooms SET name = ? WHERE id = ?', [name, id]);
    final updated = db.select('SELECT * FROM rooms WHERE id = ?', [id]).first;
    hub.broadcastRooms();
    return jsonResponse({'room': publicRoom(updated)});
  }));

  router.post('/<id>/assign-owner', withAuth(db, jwtSecret, (request, user) async {
    final adminError = requireAdmin(user);
    if (adminError != null) return adminError;

    final id = request.params['id'];
    final rooms = db.select('SELECT * FROM rooms WHERE id = ?', [id]);
    if (rooms.isEmpty) return jsonError('방을 찾을 수 없습니다.', status: 404);
    final room = rooms.first;

    final body = await readJsonBody(request);
    final userId = body['userId'];
    if (userId == null) return jsonError('소유자로 지정할 사용자를 선택해주세요.');
    final targets = db.select('SELECT * FROM users WHERE id = ?', [userId]);
    if (targets.isEmpty) return jsonError('사용자를 찾을 수 없습니다.', status: 404);

    db.execute('BEGIN');
    try {
      db.execute('UPDATE rooms SET owner_id = NULL WHERE owner_id = ?', [userId]);
      db.execute('UPDATE users SET room_id = NULL WHERE room_id = ? AND id != ?', [room['id'], userId]);
      db.execute('UPDATE rooms SET owner_id = ? WHERE id = ?', [userId, room['id']]);
      db.execute('UPDATE users SET room_id = ? WHERE id = ?', [room['id'], userId]);
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }

    final updated = db.select('SELECT * FROM rooms WHERE id = ?', [room['id']]).first;
    hub.broadcastRooms();
    hub.broadcastStatus();
    return jsonResponse({'room': publicRoom(updated)});
  }));

  router.patch('/<id>/access', withAuth(db, jwtSecret, (request, user) async {
    final id = request.params['id'];
    final rows = db.select('SELECT * FROM rooms WHERE id = ?', [id]);
    if (rows.isEmpty) return jsonError('방을 찾을 수 없습니다.', status: 404);
    final room = rows.first;

    if (room['owner_id'] != user['id'] && (user['is_admin'] as int) == 0) {
      return jsonError('해당 방의 소유자만 변경할 수 있습니다.', status: 403);
    }

    final body = await readJsonBody(request);
    final status = body['status']?.toString();
    if (status != 'open' && status != 'closed') {
      return jsonError("status는 'open' 또는 'closed'여야 합니다.");
    }

    db.execute('UPDATE rooms SET access_status = ? WHERE id = ?', [status, id]);
    final updated = db.select('SELECT * FROM rooms WHERE id = ?', [id]).first;
    hub.broadcastRooms();
    return jsonResponse({'room': publicRoom(updated)});
  }));

  // ---- 온라인 노크 ----

  router.post('/<id>/knock', withAuth(db, jwtSecret, (request, user) async {
    final id = request.params['id'];
    final rows = db.select('SELECT * FROM rooms WHERE id = ?', [id]);
    if (rows.isEmpty) return jsonError('방을 찾을 수 없습니다.', status: 404);
    final room = rows.first;

    if (room['owner_id'] == null) return jsonError('아직 소유자가 배정되지 않은 방입니다.');
    if (room['owner_id'] == user['id']) return jsonError('자신의 방에는 노크할 수 없습니다.');
    if (room['access_status'] != 'open') return jsonError('현재 출입이 제한된 방입니다.', status: 403);

    final createdAt = ServerTime.nowIso();
    db.execute(
      "INSERT INTO knocks (room_id, requester_id, status, created_at) VALUES (?, ?, 'pending', ?)",
      [room['id'], user['id'], createdAt],
    );
    final knock = {
      'id': db.lastInsertRowId,
      'roomId': room['id'],
      'roomName': room['name'],
      'requesterId': user['id'],
      'requesterName': user['display_name'],
      'status': 'pending',
      'createdAt': createdAt,
      'respondedAt': null,
    };
    hub.emitToUser(room['owner_id'] as int, 'knock:new', knock);
    return jsonResponse({'knock': knock}, status: 201);
  }));

  router.get('/knocks/mine', withAuth(db, jwtSecret, (request, user) {
    final as = request.url.queryParameters['as'] == 'incoming' ? 'incoming' : 'outgoing';
    final rows = as == 'incoming'
        ? db.select('''
            SELECT k.*, r.name AS room_name, u.display_name AS requester_name
            FROM knocks k
            JOIN rooms r ON r.id = k.room_id
            JOIN users u ON u.id = k.requester_id
            WHERE r.owner_id = ?
            ORDER BY k.created_at DESC
          ''', [user['id']])
        : db.select('''
            SELECT k.*, r.name AS room_name, u.display_name AS requester_name
            FROM knocks k
            JOIN rooms r ON r.id = k.room_id
            JOIN users u ON u.id = k.requester_id
            WHERE k.requester_id = ?
            ORDER BY k.created_at DESC
          ''', [user['id']]);
    return jsonResponse({'knocks': rows.map(_serializeKnock).toList()});
  }));

  router.post('/knocks/<knockId>/respond', withAuth(db, jwtSecret, (request, user) async {
    final knockId = request.params['knockId'];
    final rows = db.select('''
      SELECT k.*, r.owner_id AS room_owner_id, r.name AS room_name, u.display_name AS requester_name
      FROM knocks k
      JOIN rooms r ON r.id = k.room_id
      JOIN users u ON u.id = k.requester_id
      WHERE k.id = ?
    ''', [knockId]);
    if (rows.isEmpty) return jsonError('노크를 찾을 수 없습니다.', status: 404);
    final row = rows.first;

    if (row['room_owner_id'] != user['id']) return jsonError('해당 방의 소유자만 응답할 수 있습니다.', status: 403);
    if (row['status'] != 'pending') return jsonError('이미 처리된 노크입니다.', status: 409);

    final body = await readJsonBody(request);
    final approve = body['approve'] == true;
    final status = approve ? 'approved' : 'denied';
    final respondedAt = ServerTime.nowIso();
    db.execute('UPDATE knocks SET status = ?, responded_at = ? WHERE id = ?', [status, respondedAt, row['id']]);

    final knock = {
      'id': row['id'],
      'roomId': row['room_id'],
      'roomName': row['room_name'],
      'requesterId': row['requester_id'],
      'requesterName': row['requester_name'],
      'status': status,
      'createdAt': row['created_at'],
      'respondedAt': respondedAt,
    };
    hub.emitToUser(row['requester_id'] as int, 'knock:responded', knock);
    return jsonResponse({'knock': knock});
  }));

  return router;
}
