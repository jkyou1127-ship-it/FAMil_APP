import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import '../middleware/auth_middleware.dart';
import '../utils/json_response.dart';
import '../utils/kst_time.dart';

/// backend/src/routes/suggestions.js를 포팅한 라우터. 건의사항은 익명으로
/// 저장되며(작성자 정보 없음) 모두가 볼 수 있다.
Router buildSuggestionsRouter(Database db, String jwtSecret) {
  final router = Router();

  router.post('/', withAuth(db, jwtSecret, (request, user) async {
    final body = await readJsonBody(request);
    final content = body['content']?.toString().trim();
    if (content == null || content.isEmpty) return jsonError('건의 내용을 입력해주세요.');

    final createdAt = ServerTime.nowIso();
    db.execute('INSERT INTO suggestions (content, created_at) VALUES (?, ?)', [content, createdAt]);
    return jsonResponse({
      'suggestion': {'id': db.lastInsertRowId, 'content': content, 'createdAt': createdAt},
    }, status: 201);
  }));

  router.get('/', withAuth(db, jwtSecret, (request, user) {
    final rows = db.select('SELECT * FROM suggestions ORDER BY created_at DESC');
    return jsonResponse({
      'suggestions': rows.map((r) => {'id': r['id'], 'content': r['content'], 'createdAt': r['created_at']}).toList(),
    });
  }));

  return router;
}
