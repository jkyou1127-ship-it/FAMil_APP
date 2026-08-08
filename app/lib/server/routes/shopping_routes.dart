import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import '../middleware/auth_middleware.dart';
import '../realtime/realtime_hub.dart';
import '../utils/json_response.dart';
import '../utils/kst_time.dart';

Map<String, dynamic> _serialize(Row row) => {
      'id': row['id'],
      'content': row['content'],
      'bought': (row['bought'] as int) != 0,
      'addedBy': row['added_by'],
      'addedByName': row['added_by_name'],
      'boughtBy': row['bought_by'],
      'boughtByName': row['bought_by_name'],
      'createdAt': row['created_at'],
      'boughtAt': row['bought_at'],
    };

List<Map<String, dynamic>> _listItems(Database db) {
  final rows = db.select(
    'SELECT si.*, adder.display_name AS added_by_name, buyer.display_name AS bought_by_name '
    'FROM shopping_items si '
    'JOIN users adder ON adder.id = si.added_by '
    'LEFT JOIN users buyer ON buyer.id = si.bought_by '
    'ORDER BY si.bought ASC, si.created_at ASC',
  );
  return rows.map(_serialize).toList();
}

/// backend/src/routes/shopping.js를 포팅한 라우터. 온 가족이 함께 채우고
/// 체크하는 장보기 목록 — 개인 할 일과 달리 누구나 추가/체크할 수 있다.
Router buildShoppingRouter(Database db, String jwtSecret, RealtimeHub hub) {
  final router = Router();

  void broadcastList() => hub.broadcast('shopping:update', {'items': _listItems(db)});

  router.get('/', withAuth(db, jwtSecret, (request, user) {
    return jsonResponse({'items': _listItems(db)});
  }));

  router.post('/', withAuth(db, jwtSecret, (request, user) async {
    final body = await readJsonBody(request);
    final content = body['content']?.toString().trim();
    if (content == null || content.isEmpty) return jsonError('살 것을 입력해주세요.');

    db.execute(
      'INSERT INTO shopping_items (content, added_by, bought, created_at) VALUES (?, ?, 0, ?)',
      [content, user['id'], ServerTime.nowIso()],
    );
    broadcastList();
    return jsonResponse({'items': _listItems(db)}, status: 201);
  }));

  // 다 산 항목을 한 번에 정리한다 — '/<id>'보다 먼저 선언해야 'bought'가 id로 잘못 매칭되지 않는다.
  router.delete('/bought', withAuth(db, jwtSecret, (request, user) {
    db.execute('DELETE FROM shopping_items WHERE bought = 1');
    broadcastList();
    return jsonResponse({}, status: 204);
  }));

  router.patch('/<id>', withAuth(db, jwtSecret, (request, user) async {
    final id = request.params['id'];
    final rows = db.select('SELECT * FROM shopping_items WHERE id = ?', [id]);
    if (rows.isEmpty) return jsonError('항목을 찾을 수 없습니다.', status: 404);

    final body = await readJsonBody(request);
    final bought = body['bought'];
    if (bought == true) {
      db.execute(
        'UPDATE shopping_items SET bought = 1, bought_by = ?, bought_at = ? WHERE id = ?',
        [user['id'], ServerTime.nowIso(), id],
      );
    } else if (bought == false) {
      db.execute('UPDATE shopping_items SET bought = 0, bought_by = NULL, bought_at = NULL WHERE id = ?', [id]);
    }
    broadcastList();
    return jsonResponse({'items': _listItems(db)});
  }));

  router.delete('/<id>', withAuth(db, jwtSecret, (request, user) {
    final id = request.params['id'];
    if (db.select('SELECT id FROM shopping_items WHERE id = ?', [id]).isEmpty) {
      return jsonError('항목을 찾을 수 없습니다.', status: 404);
    }
    db.execute('DELETE FROM shopping_items WHERE id = ?', [id]);
    broadcastList();
    return jsonResponse({}, status: 204);
  }));

  return router;
}
