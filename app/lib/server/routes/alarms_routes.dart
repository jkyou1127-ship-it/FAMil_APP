import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import '../middleware/auth_middleware.dart';
import '../utils/json_response.dart';
import '../utils/kst_time.dart';

const _repeatTypes = ['daily', 'weekly', 'date'];
final _timeRe = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

Map<String, dynamic> _serializeAlarm(Row row) => {
      'id': row['id'],
      'label': row['label'],
      'time': row['time'],
      'repeatType': row['repeat_type'],
      'repeatDays': row['repeat_days'] != null ? json.decode(row['repeat_days'] as String) : [],
      'specificDate': row['specific_date'],
      'sound': row['sound'],
      'enabled': (row['enabled'] as int) != 0,
      'createdAt': row['created_at'],
    };

/// backend/src/routes/alarms.js를 포팅한 라우터.
Router buildAlarmsRouter(Database db, String jwtSecret) {
  final router = Router();

  router.get('/', withAuth(db, jwtSecret, (request, user) {
    final rows = db.select('SELECT * FROM alarms WHERE user_id = ? ORDER BY time', [user['id']]);
    return jsonResponse({'alarms': rows.map(_serializeAlarm).toList()});
  }));

  router.post('/', withAuth(db, jwtSecret, (request, user) async {
    final body = await readJsonBody(request);
    final time = body['time']?.toString() ?? '';
    if (!_timeRe.hasMatch(time)) return jsonError('시간은 HH:mm 형식이어야 합니다.');

    final repeatTypeInput = body['repeatType']?.toString();
    final type = _repeatTypes.contains(repeatTypeInput) ? repeatTypeInput! : 'daily';
    final repeatDays = body['repeatDays'];
    if (type == 'weekly' && (repeatDays is! List || repeatDays.isEmpty)) {
      return jsonError('요일별 반복은 최소 하나의 요일을 선택해야 합니다.');
    }
    final specificDate = body['specificDate']?.toString();
    if (type == 'date' && (specificDate == null || specificDate.isEmpty)) {
      return jsonError('날짜를 정해서 울리려면 날짜를 선택해야 합니다.');
    }

    final createdAt = ServerTime.nowIso();
    db.execute(
      '''INSERT INTO alarms (user_id, label, time, repeat_type, repeat_days, specific_date, sound, enabled, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?)''',
      [
        user['id'],
        body['label']?.toString(),
        time,
        type,
        type == 'weekly' ? json.encode(repeatDays) : null,
        type == 'date' ? specificDate : null,
        body['sound']?.toString() ?? 'tone1',
        createdAt,
      ],
    );
    final row = db.select('SELECT * FROM alarms WHERE id = ?', [db.lastInsertRowId]).first;
    return jsonResponse({'alarm': _serializeAlarm(row)}, status: 201);
  }));

  router.patch('/<id>', withAuth(db, jwtSecret, (request, user) async {
    final id = request.params['id'];
    final rows = db.select('SELECT * FROM alarms WHERE id = ? AND user_id = ?', [id, user['id']]);
    if (rows.isEmpty) return jsonError('알람을 찾을 수 없습니다.', status: 404);
    final row = rows.first;

    final body = await readJsonBody(request);
    final time = body.containsKey('time') ? body['time']?.toString() : null;
    if (time != null && !_timeRe.hasMatch(time)) return jsonError('시간은 HH:mm 형식이어야 합니다.');

    final type = body.containsKey('repeatType') ? body['repeatType']?.toString() : row['repeat_type'] as String;
    if (!_repeatTypes.contains(type)) return jsonError('올바르지 않은 반복 유형입니다.');

    final repeatDays = body.containsKey('repeatDays')
        ? body['repeatDays']
        : (row['repeat_days'] != null ? json.decode(row['repeat_days'] as String) : []);
    final specificDate = body.containsKey('specificDate') ? body['specificDate']?.toString() : row['specific_date'];

    db.execute(
      '''UPDATE alarms SET
           label = ?, time = ?, repeat_type = ?, repeat_days = ?, specific_date = ?, sound = ?, enabled = ?
         WHERE id = ?''',
      [
        body.containsKey('label') ? body['label']?.toString() : row['label'],
        time ?? row['time'],
        type,
        type == 'weekly' ? json.encode(repeatDays) : null,
        type == 'date' ? specificDate : null,
        body.containsKey('sound') ? body['sound']?.toString() : row['sound'],
        body.containsKey('enabled') ? (body['enabled'] == true ? 1 : 0) : row['enabled'],
        row['id'],
      ],
    );
    final updated = db.select('SELECT * FROM alarms WHERE id = ?', [row['id']]).first;
    return jsonResponse({'alarm': _serializeAlarm(updated)});
  }));

  router.delete('/<id>', withAuth(db, jwtSecret, (request, user) {
    final id = request.params['id'];
    db.execute('DELETE FROM alarms WHERE id = ? AND user_id = ?', [id, user['id']]);
    if (db.updatedRows == 0) return jsonError('알람을 찾을 수 없습니다.', status: 404);
    return Response(204);
  }));

  return router;
}
