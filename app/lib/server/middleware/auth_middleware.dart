import 'dart:async';

import 'package:shelf/shelf.dart';
import 'package:sqlite3/sqlite3.dart';

import '../utils/json_response.dart';
import '../utils/jwt.dart';

typedef AuthedHandler = FutureOr<Response> Function(Request request, Row user);

/// backend/src/middleware/auth.js의 authRequired와 동일한 검증을 수행한 뒤
/// 사용자 행(Row)을 핸들러에 전달한다.
Handler withAuth(Database db, String jwtSecret, AuthedHandler inner) {
  return (Request request) async {
    final header = request.headers['authorization'] ?? '';
    final token = header.startsWith('Bearer ') ? header.substring(7) : null;
    if (token == null) return jsonError('로그인이 필요합니다.', status: 401);

    try {
      final payload = Jwt.verify(token, jwtSecret);
      final rows = db.select('SELECT * FROM users WHERE id = ?', [payload['id']]);
      if (rows.isEmpty) return jsonError('존재하지 않는 사용자입니다.', status: 401);
      return await inner(request, rows.first);
    } on JwtException {
      return jsonError('유효하지 않은 토큰입니다.', status: 401);
    }
  };
}

/// 관리자 전용 핸들러 앞에서 호출한다 — 에러 응답이면 그대로 반환, 통과하면 null.
Response? requireAdmin(Row user) {
  if ((user['is_admin'] as int) == 0) {
    return jsonError('관리자만 접근할 수 있습니다.', status: 403);
  }
  return null;
}
