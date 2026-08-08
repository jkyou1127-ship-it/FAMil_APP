import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import '../middleware/auth_middleware.dart';
import '../realtime/realtime_hub.dart';
import '../utils/json_response.dart';
import '../utils/kst_time.dart';

Map<String, dynamic> _serializeRoom(Row row) => {
      'id': row['id'],
      'name': row['name'],
      'createdBy': row['created_by'],
      'createdAt': row['created_at'],
    };

Map<String, dynamic> _serializeMessage(Row row) => {
      'id': row['id'],
      'roomId': row['room_id'],
      'senderId': row['sender_id'],
      'senderName': row['sender_name'],
      'content': row['content'],
      'createdAt': row['created_at'],
    };

bool _isMember(Database db, int roomId, int userId) =>
    db.select('SELECT 1 FROM chat_room_members WHERE room_id = ? AND user_id = ?', [roomId, userId]).isNotEmpty;

List<int> _memberIds(Database db, int roomId) =>
    db.select('SELECT user_id FROM chat_room_members WHERE room_id = ?', [roomId]).map((r) => r['user_id'] as int).toList();

int? _asInt(Object? value) => value is int ? value : int.tryParse(value?.toString() ?? '');

/// REST 발신(POST /chat-rooms/:id/messages)과 소켓 발신(group:message:send)이
/// 공유하는 발신 로직. backend/src/sockets/index.js의 group:message:send
/// 핸들러와 동일한 동작을 한다 (FCM 푸시는 아직 이식하지 않았다).
Map<String, dynamic> _sendGroupMessage(Database db, RealtimeHub hub, int userId, Object? roomIdRaw, String? content) {
  final roomId = _asInt(roomIdRaw);
  final trimmed = content?.trim();
  if (roomId == null || trimmed == null || trimmed.isEmpty) {
    return {'error': '메시지 내용을 입력해주세요.'};
  }
  if (!_isMember(db, roomId, userId)) {
    return {'error': '해당 단톡방의 멤버만 보낼 수 있습니다.'};
  }

  final createdAt = ServerTime.nowIso();
  db.execute(
    'INSERT INTO chat_room_messages (room_id, sender_id, content, created_at) VALUES (?, ?, ?, ?)',
    [roomId, userId, trimmed, createdAt],
  );
  final senderRows = db.select('SELECT display_name FROM users WHERE id = ?', [userId]);
  final message = {
    'id': db.lastInsertRowId,
    'roomId': roomId,
    'senderId': userId,
    'senderName': senderRows.isEmpty ? null : senderRows.first['display_name'],
    'content': trimmed,
    'createdAt': createdAt,
  };

  for (final memberId in _memberIds(db, roomId)) {
    hub.emitToUser(memberId, 'group:message:new', message);
  }
  return {'message': message};
}

/// backend/src/routes/chatRooms.js + sockets/index.js의 group:message:send를 포팅한 라우터.
Router buildChatRoomsRouter(Database db, String jwtSecret, RealtimeHub hub) {
  final router = Router();

  router.get('/', withAuth(db, jwtSecret, (request, user) {
    final meId = user['id'] as int;
    final rooms = db.select(
      'SELECT cr.*, crm.last_read_at FROM chat_rooms cr '
      'JOIN chat_room_members crm ON crm.room_id = cr.id '
      'WHERE crm.user_id = ? ORDER BY cr.created_at DESC',
      [meId],
    );

    final result = rooms.map((room) {
      final roomId = room['id'] as int;
      final members = db.select(
        'SELECT u.id, u.display_name FROM chat_room_members crm '
        'JOIN users u ON u.id = crm.user_id WHERE crm.room_id = ?',
        [roomId],
      );
      final lastMessageRows =
          db.select('SELECT * FROM chat_room_messages WHERE room_id = ? ORDER BY created_at DESC LIMIT 1', [roomId]);
      final lastReadAt = room['last_read_at'];
      final unreadCount = db.select(
        'SELECT COUNT(*) AS c FROM chat_room_messages WHERE room_id = ? AND sender_id != ? AND (? IS NULL OR created_at > ?)',
        [roomId, meId, lastReadAt, lastReadAt],
      ).first['c'];

      Map<String, dynamic>? lastMessage;
      if (lastMessageRows.isNotEmpty) {
        final row = lastMessageRows.first;
        final senderRows = db.select('SELECT display_name FROM users WHERE id = ?', [row['sender_id']]);
        lastMessage = {
          'id': row['id'],
          'roomId': row['room_id'],
          'senderId': row['sender_id'],
          'senderName': senderRows.isEmpty ? null : senderRows.first['display_name'],
          'content': row['content'],
          'createdAt': row['created_at'],
        };
      }

      return {
        ..._serializeRoom(room),
        'members': members.map((m) => {'id': m['id'], 'displayName': m['display_name']}).toList(),
        'lastMessage': lastMessage,
        'unreadCount': unreadCount,
      };
    }).toList();

    result.sort((a, b) {
      final at = (a['lastMessage'] as Map?)?['createdAt'] as String? ?? a['createdAt'] as String;
      final bt = (b['lastMessage'] as Map?)?['createdAt'] as String? ?? b['createdAt'] as String;
      return bt.compareTo(at);
    });

    return jsonResponse({'rooms': result});
  }));

  router.post('/', withAuth(db, jwtSecret, (request, user) async {
    final meId = user['id'] as int;
    final body = await readJsonBody(request);
    final name = body['name']?.toString().trim();
    final ids = body['memberIds'];
    if (name == null || name.isEmpty) return jsonError('방 이름을 입력해주세요.');
    if (ids is! List || ids.isEmpty) return jsonError('초대할 사람을 한 명 이상 선택해주세요.');

    final createdAt = ServerTime.nowIso();
    db.execute('INSERT INTO chat_rooms (name, created_by, created_at) VALUES (?, ?, ?)', [name, meId, createdAt]);
    final roomId = db.lastInsertRowId;

    final uniqueMemberIds = {meId, ...ids.map((e) => _asInt(e)).whereType<int>()};
    for (final memberId in uniqueMemberIds) {
      if (db.select('SELECT id FROM users WHERE id = ?', [memberId]).isNotEmpty) {
        db.execute(
          'INSERT INTO chat_room_members (room_id, user_id, joined_at) VALUES (?, ?, ?)',
          [roomId, memberId, createdAt],
        );
      }
    }

    final room = db.select('SELECT * FROM chat_rooms WHERE id = ?', [roomId]).first;
    for (final memberId in uniqueMemberIds) {
      if (memberId != meId) hub.emitToUser(memberId, 'group:room:new', _serializeRoom(room));
    }
    return jsonResponse({'room': _serializeRoom(room)}, status: 201);
  }));

  router.get('/<roomId>/messages', withAuth(db, jwtSecret, (request, user) {
    final meId = user['id'] as int;
    final roomId = _asInt(request.params['roomId']);
    if (roomId == null) return jsonError('잘못된 요청입니다.');
    if (!_isMember(db, roomId, meId)) return jsonError('해당 단톡방의 멤버만 볼 수 있습니다.', status: 403);

    final rows = db.select(
      'SELECT crm.*, u.display_name AS sender_name FROM chat_room_messages crm '
      'JOIN users u ON u.id = crm.sender_id WHERE crm.room_id = ? ORDER BY crm.created_at ASC',
      [roomId],
    );
    db.execute(
      'UPDATE chat_room_members SET last_read_at = ? WHERE room_id = ? AND user_id = ?',
      [ServerTime.nowIso(), roomId, meId],
    );
    return jsonResponse({'messages': rows.map(_serializeMessage).toList()});
  }));

  // 소켓을 사용할 수 없는 환경을 위한 REST 발신 경로 (소켓과 동일하게 동작).
  router.post('/<roomId>/messages', withAuth(db, jwtSecret, (request, user) async {
    final roomId = _asInt(request.params['roomId']);
    if (roomId == null) return jsonError('잘못된 요청입니다.');
    final body = await readJsonBody(request);
    final result = _sendGroupMessage(db, hub, user['id'] as int, roomId, body['content']?.toString());
    if (result.containsKey('error')) return jsonError(result['error'] as String);
    return jsonResponse(result, status: 201);
  }));

  router.post('/<roomId>/members', withAuth(db, jwtSecret, (request, user) async {
    final meId = user['id'] as int;
    final roomId = _asInt(request.params['roomId']);
    if (roomId == null) return jsonError('잘못된 요청입니다.');
    if (!_isMember(db, roomId, meId)) return jsonError('해당 단톡방의 멤버만 초대할 수 있습니다.', status: 403);

    final body = await readJsonBody(request);
    final userId = _asInt(body['userId']);
    if (userId == null) return jsonError('초대할 사용자를 선택해주세요.');
    if (db.select('SELECT id FROM users WHERE id = ?', [userId]).isEmpty) {
      return jsonError('사용자를 찾을 수 없습니다.', status: 404);
    }
    if (_isMember(db, roomId, userId)) return jsonError('이미 참여 중인 사용자입니다.', status: 409);

    db.execute(
      'INSERT INTO chat_room_members (room_id, user_id, joined_at) VALUES (?, ?, ?)',
      [roomId, userId, ServerTime.nowIso()],
    );
    final room = db.select('SELECT * FROM chat_rooms WHERE id = ?', [roomId]).first;
    hub.emitToUser(userId, 'group:room:new', _serializeRoom(room));
    return jsonResponse({}, status: 204);
  }));

  router.delete('/<roomId>/members/me', withAuth(db, jwtSecret, (request, user) {
    final meId = user['id'] as int;
    final roomId = _asInt(request.params['roomId']);
    if (roomId == null) return jsonError('잘못된 요청입니다.');
    if (!_isMember(db, roomId, meId)) return jsonError('참여 중인 단톡방이 아닙니다.', status: 404);

    db.execute('DELETE FROM chat_room_members WHERE room_id = ? AND user_id = ?', [roomId, meId]);
    return jsonResponse({}, status: 204);
  }));

  hub.on('group:message:send', (userId, data, ack) {
    final result = _sendGroupMessage(db, hub, userId, data['roomId'], data['content']?.toString());
    ack(result);
  });

  return router;
}
