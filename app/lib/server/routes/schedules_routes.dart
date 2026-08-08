import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import '../middleware/auth_middleware.dart';
import '../utils/json_response.dart';
import '../utils/kst_time.dart';

final _dateRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');

Map<String, dynamic> _serializeSchedule(Row row) =>
    {'id': row['id'], 'date': row['date'], 'content': row['content'], 'createdAt': row['created_at']};

/// backend/src/routes/schedules.js를 포팅한 라우터.
Router buildSchedulesRouter(Database db, String jwtSecret) {
  final router = Router();

  router.get('/', withAuth(db, jwtSecret, (request, user) {
    final month = request.url.queryParameters['month'];
    final rows = month != null
        ? db.select('SELECT * FROM schedules WHERE user_id = ? AND date LIKE ? ORDER BY date', [user['id'], '$month%'])
        : db.select('SELECT * FROM schedules WHERE user_id = ? ORDER BY date', [user['id']]);
    return jsonResponse({'schedules': rows.map(_serializeSchedule).toList()});
  }));

  router.post('/', withAuth(db, jwtSecret, (request, user) async {
    final body = await readJsonBody(request);
    final date = body['date']?.toString() ?? '';
    if (!_dateRe.hasMatch(date)) return jsonError('날짜는 YYYY-MM-DD 형식이어야 합니다.');
    final content = body['content']?.toString().trim();
    if (content == null || content.isEmpty) return jsonError('일정 내용을 입력해주세요.');

    final createdAt = ServerTime.nowIso();
    db.execute('INSERT INTO schedules (user_id, date, content, created_at) VALUES (?, ?, ?, ?)', [user['id'], date, content, createdAt]);
    final row = db.select('SELECT * FROM schedules WHERE id = ?', [db.lastInsertRowId]).first;
    return jsonResponse({'schedule': _serializeSchedule(row)}, status: 201);
  }));

  router.patch('/<id>', withAuth(db, jwtSecret, (request, user) async {
    final id = request.params['id'];
    final rows = db.select('SELECT * FROM schedules WHERE id = ? AND user_id = ?', [id, user['id']]);
    if (rows.isEmpty) return jsonError('일정을 찾을 수 없습니다.', status: 404);
    final row = rows.first;

    final body = await readJsonBody(request);
    final date = body.containsKey('date') ? body['date']?.toString() : null;
    if (date != null && !_dateRe.hasMatch(date)) return jsonError('날짜는 YYYY-MM-DD 형식이어야 합니다.');

    db.execute(
      'UPDATE schedules SET date = ?, content = ? WHERE id = ?',
      [
        date ?? row['date'],
        body.containsKey('content') ? body['content']?.toString().trim() : row['content'],
        row['id'],
      ],
    );
    final updated = db.select('SELECT * FROM schedules WHERE id = ?', [row['id']]).first;
    return jsonResponse({'schedule': _serializeSchedule(updated)});
  }));

  router.delete('/<id>', withAuth(db, jwtSecret, (request, user) {
    final id = request.params['id'];
    db.execute('DELETE FROM schedules WHERE id = ? AND user_id = ?', [id, user['id']]);
    if (db.updatedRows == 0) return jsonError('일정을 찾을 수 없습니다.', status: 404);
    return Response(204);
  }));

  return router;
}
