import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import '../middleware/auth_middleware.dart';
import '../utils/json_response.dart';
import '../utils/kst_time.dart';

Map<String, dynamic> _serializeTodo(Row row) => {
      'id': row['id'],
      'content': row['content'],
      'completed': (row['completed'] as int) != 0,
      'completedDate': row['completed_date'],
      'createdAt': row['created_at'],
    };

/// backend/src/routes/todos.js를 포팅한 라우터.
Router buildTodosRouter(Database db, String jwtSecret) {
  final router = Router();

  router.get('/', withAuth(db, jwtSecret, (request, user) {
    final rows = db.select('SELECT * FROM todos WHERE user_id = ? ORDER BY completed, created_at DESC', [user['id']]);
    return jsonResponse({'todos': rows.map(_serializeTodo).toList()});
  }));

  router.post('/', withAuth(db, jwtSecret, (request, user) async {
    final body = await readJsonBody(request);
    final content = body['content']?.toString().trim();
    if (content == null || content.isEmpty) return jsonError('할 일 내용을 입력해주세요.');

    final createdAt = ServerTime.nowIso();
    db.execute('INSERT INTO todos (user_id, content, created_at) VALUES (?, ?, ?)', [user['id'], content, createdAt]);
    final row = db.select('SELECT * FROM todos WHERE id = ?', [db.lastInsertRowId]).first;
    return jsonResponse({'todo': _serializeTodo(row)}, status: 201);
  }));

  // 완료 시 취소선 + 회색 처리(클라이언트), 완료된 날짜를 기록해 자정 정리 작업이 사용한다.
  router.patch('/<id>', withAuth(db, jwtSecret, (request, user) async {
    final id = request.params['id'];
    final rows = db.select('SELECT * FROM todos WHERE id = ? AND user_id = ?', [id, user['id']]);
    if (rows.isEmpty) return jsonError('할 일을 찾을 수 없습니다.', status: 404);
    final row = rows.first;

    final body = await readJsonBody(request);
    final nextCompleted = body.containsKey('completed') ? body['completed'] == true : (row['completed'] as int) != 0;
    final completedDate = nextCompleted ? (row['completed_date'] ?? ServerTime.kstDateString()) : null;

    db.execute(
      'UPDATE todos SET content = ?, completed = ?, completed_date = ? WHERE id = ?',
      [
        body.containsKey('content') ? body['content']?.toString().trim() : row['content'],
        nextCompleted ? 1 : 0,
        completedDate,
        row['id'],
      ],
    );
    final updated = db.select('SELECT * FROM todos WHERE id = ?', [row['id']]).first;
    return jsonResponse({'todo': _serializeTodo(updated)});
  }));

  router.delete('/<id>', withAuth(db, jwtSecret, (request, user) {
    final id = request.params['id'];
    db.execute('DELETE FROM todos WHERE id = ? AND user_id = ?', [id, user['id']]);
    if (db.updatedRows == 0) return jsonError('할 일을 찾을 수 없습니다.', status: 404);
    return Response(204);
  }));

  return router;
}
