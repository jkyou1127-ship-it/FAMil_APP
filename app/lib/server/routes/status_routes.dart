import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import '../middleware/auth_middleware.dart';
import '../utils/json_response.dart';
import '../utils/kst_time.dart';

/// backend/src/routes/status.js를 포팅한 라우터 (상태창).
Router buildStatusRouter(Database db, String jwtSecret) {
  final router = Router();

  router.get('/', withAuth(db, jwtSecret, (request, user) {
    final users = db.select('SELECT * FROM users ORDER BY id');
    final today = ServerTime.kstDateString();

    final board = users.map((u) {
      final roomId = u['room_id'];
      final roomRows = roomId != null ? db.select('SELECT * FROM rooms WHERE id = ?', [roomId]) : const <Row>[];
      final todaySchedules = db
          .select('SELECT content FROM schedules WHERE user_id = ? AND date = ? ORDER BY id', [u['id'], today])
          .map((s) => s['content'])
          .toList();

      return {
        'userId': u['id'],
        'displayName': u['display_name'],
        'profilePhoto': u['profile_photo'],
        'online': (u['online'] as int) != 0,
        'sleepStatus': u['sleep_status'],
        'isAdmin': (u['is_admin'] as int) != 0,
        'room': roomRows.isEmpty
            ? null
            : {
                'id': roomRows.first['id'],
                'name': roomRows.first['name'],
                'accessStatus': roomRows.first['access_status'],
                'knockEnabled': roomRows.first['access_status'] == 'open',
              },
        'todaySchedules': todaySchedules,
      };
    }).toList();

    return jsonResponse({'date': today, 'board': board});
  }));

  return router;
}
