import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import '../middleware/auth_middleware.dart';
import '../realtime/realtime_hub.dart';
import '../utils/json_response.dart';
import '../utils/kst_time.dart';

Map<String, dynamic> _serializeMessage(Row row) => {
      'id': row['id'],
      'senderId': row['sender_id'],
      'receiverId': row['receiver_id'],
      'content': row['content'],
      'createdAt': row['created_at'],
      'readAt': row['read_at'],
    };

int? _asInt(Object? value) => value is int ? value : int.tryParse(value?.toString() ?? '');

/// REST 발신(POST /messages)과 소켓 발신(message:send)이 공유하는 발신 로직.
/// backend/src/sockets/index.js의 message:send 핸들러와 동일한 동작을 한다.
Map<String, dynamic> _sendMessage(Database db, RealtimeHub hub, int senderId, Object? receiverIdRaw, String? content) {
  final receiverId = _asInt(receiverIdRaw);
  final trimmed = content?.trim();
  if (receiverId == null || trimmed == null || trimmed.isEmpty) {
    return {'error': '메시지 내용을 입력해주세요.'};
  }
  if (db.select('SELECT id FROM users WHERE id = ?', [receiverId]).isEmpty) {
    return {'error': '상대방을 찾을 수 없습니다.'};
  }

  final createdAt = ServerTime.nowIso();
  db.execute(
    'INSERT INTO messages (sender_id, receiver_id, content, created_at) VALUES (?, ?, ?, ?)',
    [senderId, receiverId, trimmed, createdAt],
  );
  final message = {
    'id': db.lastInsertRowId,
    'senderId': senderId,
    'receiverId': receiverId,
    'content': trimmed,
    'createdAt': createdAt,
    'readAt': null,
  };
  hub.emitToUser(receiverId, 'message:new', message);
  hub.emitToUser(senderId, 'message:new', message);
  return {'message': message};
}

/// backend/src/routes/messages.js + sockets/index.js의 message:send를 포팅한 라우터.
Router buildMessagesRouter(Database db, String jwtSecret, RealtimeHub hub) {
  final router = Router();

  router.get('/conversations', withAuth(db, jwtSecret, (request, user) {
    final meId = user['id'] as int;
    final partnerIds = db
        .select(
          'SELECT DISTINCT CASE WHEN sender_id = ? THEN receiver_id ELSE sender_id END AS partner_id '
          'FROM messages WHERE sender_id = ? OR receiver_id = ?',
          [meId, meId, meId],
        )
        .map((r) => r['partner_id'])
        .toList();

    final conversations = partnerIds.map((partnerId) {
      final partnerRows = db.select('SELECT id, display_name, profile_photo, online FROM users WHERE id = ?', [partnerId]);
      final lastMessageRows = db.select(
        'SELECT * FROM messages WHERE (sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?) '
        'ORDER BY created_at DESC LIMIT 1',
        [meId, partnerId, partnerId, meId],
      );
      final unreadCount = db.select(
        'SELECT COUNT(*) AS c FROM messages WHERE sender_id = ? AND receiver_id = ? AND read_at IS NULL',
        [partnerId, meId],
      ).first['c'];

      return {
        'partner': partnerRows.isEmpty
            ? null
            : {
                'id': partnerRows.first['id'],
                'displayName': partnerRows.first['display_name'],
                'profilePhoto': partnerRows.first['profile_photo'],
                'online': (partnerRows.first['online'] as int) != 0,
              },
        'lastMessage': lastMessageRows.isEmpty ? null : _serializeMessage(lastMessageRows.first),
        'unreadCount': unreadCount,
      };
    }).toList();

    conversations.sort((a, b) {
      final at = (a['lastMessage'] as Map?)?['createdAt'] as String? ?? '';
      final bt = (b['lastMessage'] as Map?)?['createdAt'] as String? ?? '';
      return bt.compareTo(at);
    });

    return jsonResponse({'conversations': conversations});
  }));

  router.get('/<userId>', withAuth(db, jwtSecret, (request, user) {
    final meId = user['id'] as int;
    final partnerId = _asInt(request.params['userId']);
    if (partnerId == null) return jsonError('잘못된 요청입니다.');

    final rows = db.select(
      'SELECT * FROM messages WHERE (sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?) '
      'ORDER BY created_at ASC',
      [meId, partnerId, partnerId, meId],
    );

    db.execute(
      'UPDATE messages SET read_at = ? WHERE sender_id = ? AND receiver_id = ? AND read_at IS NULL',
      [ServerTime.nowIso(), partnerId, meId],
    );

    return jsonResponse({'messages': rows.map(_serializeMessage).toList()});
  }));

  // 소켓을 사용할 수 없는 환경을 위한 REST 발신 경로 (소켓과 동일하게 동작).
  router.post('/', withAuth(db, jwtSecret, (request, user) async {
    final body = await readJsonBody(request);
    final result = _sendMessage(db, hub, user['id'] as int, body['receiverId'], body['content']?.toString());
    if (result.containsKey('error')) return jsonError(result['error'] as String);
    return jsonResponse(result, status: 201);
  }));

  hub.on('message:send', (userId, data, ack) {
    final result = _sendMessage(db, hub, userId, data['receiverId'], data['content']?.toString());
    ack(result);
  });

  return router;
}
