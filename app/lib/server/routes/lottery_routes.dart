import 'dart:convert';
import 'dart:math';

import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import '../middleware/auth_middleware.dart';
import '../realtime/realtime_hub.dart';
import '../utils/json_response.dart';
import '../utils/kst_time.dart';

/// backend/src/routes/lottery.js를 포팅한 라우터.
Router buildLotteryRouter(Database db, String jwtSecret, RealtimeHub hub) {
  final router = Router();
  final random = Random();

  router.post('/draw', withAuth(db, jwtSecret, (request, user) {
    final online = db.select('SELECT id, display_name FROM users WHERE online = 1');
    if (online.isEmpty) return jsonError('현재 온라인인 사용자가 없습니다.');

    final winner = online[random.nextInt(online.length)];
    final createdAt = ServerTime.nowIso();
    final participantIds = online.map((u) => u['id']).toList();

    db.execute(
      'INSERT INTO lottery_draws (winner_id, participant_ids, drawn_by, created_at) VALUES (?, ?, ?, ?)',
      [winner['id'], json.encode(participantIds), user['id'], createdAt],
    );

    final result = {
      'winnerId': winner['id'],
      'winnerName': winner['display_name'],
      'participantIds': participantIds,
      'drawnBy': user['id'],
      'createdAt': createdAt,
    };
    hub.broadcast('lottery:drawn', result);
    return jsonResponse({'result': result}, status: 201);
  }));

  router.get('/history', withAuth(db, jwtSecret, (request, user) {
    final rows = db.select('''
      SELECT ld.*, u.display_name AS winner_name
      FROM lottery_draws ld JOIN users u ON u.id = ld.winner_id
      ORDER BY ld.created_at DESC LIMIT 50
    ''');
    return jsonResponse({
      'history': rows
          .map((r) => {
                'id': r['id'],
                'winnerId': r['winner_id'],
                'winnerName': r['winner_name'],
                'participantIds': json.decode(r['participant_ids'] as String),
                'drawnBy': r['drawn_by'],
                'createdAt': r['created_at'],
              })
          .toList(),
    });
  }));

  return router;
}
