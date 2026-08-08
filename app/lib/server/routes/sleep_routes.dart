import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import '../middleware/auth_middleware.dart';
import '../realtime/realtime_hub.dart';
import '../utils/json_response.dart';
import '../utils/kst_time.dart';

Map<String, dynamic> _serializeRecord(Row row) {
  final wakeAt = row['wake_at'] as String?;
  int? durationMinutes;
  if (wakeAt != null) {
    final sleepAt = DateTime.parse(row['sleep_at'] as String);
    final wake = DateTime.parse(wakeAt);
    durationMinutes = (wake.difference(sleepAt).inSeconds / 60).round();
  }
  return {
    'id': row['id'],
    'sleepAt': row['sleep_at'],
    'wakeAt': wakeAt,
    'durationMinutes': durationMinutes,
  };
}

/// backend/src/routes/sleep.js를 포팅한 라우터.
Router buildSleepRouter(Database db, String jwtSecret, RealtimeHub hub) {
  final router = Router();

  router.post('/start', withAuth(db, jwtSecret, (request, user) {
    final open = db.select('SELECT id FROM sleep_records WHERE user_id = ? AND wake_at IS NULL', [user['id']]);
    if (open.isNotEmpty) return jsonError('이미 취침 중입니다. 먼저 기상해주세요.', status: 409);

    final sleepAt = ServerTime.nowIso();
    db.execute('INSERT INTO sleep_records (user_id, sleep_at, created_at) VALUES (?, ?, ?)', [user['id'], sleepAt, sleepAt]);
    db.execute("UPDATE users SET sleep_status = 'sleeping' WHERE id = ?", [user['id']]);
    hub.broadcastStatus();

    final record = db.select('SELECT * FROM sleep_records WHERE id = ?', [db.lastInsertRowId]).first;
    return jsonResponse({'record': _serializeRecord(record)}, status: 201);
  }));

  router.post('/wake', withAuth(db, jwtSecret, (request, user) {
    final open = db.select(
      'SELECT * FROM sleep_records WHERE user_id = ? AND wake_at IS NULL ORDER BY id DESC LIMIT 1',
      [user['id']],
    );
    if (open.isEmpty) return jsonError('취침 기록이 없습니다.', status: 409);

    final wakeAt = ServerTime.nowIso();
    db.execute('UPDATE sleep_records SET wake_at = ? WHERE id = ?', [wakeAt, open.first['id']]);
    db.execute("UPDATE users SET sleep_status = 'awake' WHERE id = ?", [user['id']]);
    hub.broadcastStatus();

    final record = db.select('SELECT * FROM sleep_records WHERE id = ?', [open.first['id']]).first;
    return jsonResponse({'record': _serializeRecord(record)});
  }));

  router.patch('/sound', withAuth(db, jwtSecret, (request, user) async {
    final body = await readJsonBody(request);
    final enabled = body['enabled'] == true;
    final soundId = body['soundId']?.toString();
    if (soundId != null && soundId.isNotEmpty) {
      db.execute(
        'UPDATE users SET sleep_sound_enabled = ?, sleep_sound_id = ? WHERE id = ?',
        [enabled ? 1 : 0, soundId, user['id']],
      );
    } else {
      db.execute('UPDATE users SET sleep_sound_enabled = ? WHERE id = ?', [enabled ? 1 : 0, user['id']]);
    }
    final updated = db.select('SELECT sleep_sound_enabled, sleep_sound_id FROM users WHERE id = ?', [user['id']]).first;
    return jsonResponse({
      'sleepSoundEnabled': (updated['sleep_sound_enabled'] as int) != 0,
      'sleepSoundId': updated['sleep_sound_id'],
    });
  }));

  router.get('/records', withAuth(db, jwtSecret, (request, user) {
    final rows = db.select('SELECT * FROM sleep_records WHERE user_id = ? ORDER BY sleep_at DESC LIMIT 30', [user['id']]);
    return jsonResponse({'records': rows.map(_serializeRecord).toList()});
  }));

  return router;
}
