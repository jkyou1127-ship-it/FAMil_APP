import 'package:bcrypt/bcrypt.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import '../middleware/auth_middleware.dart';
import '../utils/jwt.dart';
import '../utils/json_response.dart';
import '../utils/kst_time.dart';
import '../utils/serialize.dart';

/// backend/src/routes/auth.js를 그대로 포팅한 라우터.
Router buildAuthRouter(Database db, String jwtSecret) {
  final router = Router();

  String issueToken(Row user) => Jwt.sign({'id': user['id']}, jwtSecret);

  router.post('/register', (Request request) async {
    final body = await readJsonBody(request);
    final username = body['username']?.toString();
    final password = body['password']?.toString();
    final displayName = body['displayName']?.toString();
    if (username == null || username.isEmpty || password == null || password.isEmpty || displayName == null || displayName.isEmpty) {
      return jsonError('아이디, 비밀번호, 이름을 모두 입력해주세요.');
    }
    if (password.length < 4) {
      return jsonError('비밀번호는 4자 이상이어야 합니다.');
    }

    final existing = db.select('SELECT id FROM users WHERE username = ?', [username]);
    if (existing.isNotEmpty) return jsonError('이미 사용 중인 아이디입니다.', status: 409);

    final userCount = db.select('SELECT COUNT(*) AS c FROM users').first['c'] as int;
    final isAdmin = userCount == 0 ? 1 : 0;
    final passwordHash = BCrypt.hashpw(password, BCrypt.gensalt());
    final createdAt = ServerTime.nowIso();

    db.execute(
      'INSERT INTO users (username, password_hash, display_name, is_admin, created_at) VALUES (?, ?, ?, ?, ?)',
      [username, passwordHash, displayName, isAdmin, createdAt],
    );
    final user = db.select('SELECT * FROM users WHERE id = ?', [db.lastInsertRowId]).first;
    final token = issueToken(user);
    return jsonResponse({'token': token, 'user': publicUser(user)}, status: 201);
  });

  router.post('/login', (Request request) async {
    final body = await readJsonBody(request);
    final username = body['username']?.toString();
    final password = body['password']?.toString();
    if (username == null || username.isEmpty || password == null || password.isEmpty) {
      return jsonError('아이디와 비밀번호를 입력해주세요.');
    }

    final rows = db.select('SELECT * FROM users WHERE username = ?', [username]);
    if (rows.isEmpty || !BCrypt.checkpw(password, rows.first['password_hash'] as String)) {
      return jsonError('아이디 또는 비밀번호가 올바르지 않습니다.', status: 401);
    }
    final user = rows.first;
    final token = issueToken(user);
    return jsonResponse({'token': token, 'user': publicUser(user)});
  });

  router.get('/me', withAuth(db, jwtSecret, (request, user) {
    return jsonResponse({'user': publicUser(user)});
  }));

  return router;
}
