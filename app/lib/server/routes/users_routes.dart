import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_multipart/shelf_multipart.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import '../middleware/auth_middleware.dart';
import '../realtime/realtime_hub.dart';
import '../utils/json_response.dart';
import '../utils/kst_time.dart';
import '../utils/serialize.dart';

/// backend/src/routes/users.js를 그대로 포팅한 라우터.
/// [uploadsDir]는 프로필 사진이 저장되는 `uploads/` 폴더의 절대 경로다.
Router buildUsersRouter(Database db, String jwtSecret, RealtimeHub hub, {required String uploadsDir}) {
  final router = Router();

  router.get('/', withAuth(db, jwtSecret, (request, user) {
    final users = db.select('SELECT * FROM users ORDER BY id').map(publicUser).toList();
    return jsonResponse({'users': users});
  }));

  router.patch('/me', withAuth(db, jwtSecret, (request, user) async {
    final body = await readJsonBody(request);
    final displayName = body['displayName']?.toString().trim();
    if (displayName != null && displayName.isNotEmpty) {
      db.execute('UPDATE users SET display_name = ? WHERE id = ?', [displayName, user['id']]);
    }
    final updated = db.select('SELECT * FROM users WHERE id = ?', [user['id']]).first;
    hub.broadcastStatus();
    return jsonResponse({'user': publicUser(updated)});
  }));

  router.post('/me/photo', withAuth(db, jwtSecret, (request, user) async {
    final form = request.formData();
    if (form == null) return jsonError('이미지 파일을 첨부해주세요.');

    String? savedUrl;
    await for (final data in form.formData) {
      if (data.name != 'photo' || data.filename == null) continue;
      final contentType = data.part.headers['content-type'] ?? '';
      if (!contentType.startsWith('image/')) {
        return jsonError('이미지 파일만 업로드할 수 있습니다.');
      }
      final bytes = await data.part.readBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        return jsonError('파일 크기는 5MB를 초과할 수 없습니다.');
      }
      final ext = p.extension(data.filename!).isEmpty ? '.jpg' : p.extension(data.filename!);
      final outName = 'user${user['id']}_${DateTime.now().millisecondsSinceEpoch}$ext';
      final dir = Directory(p.join(uploadsDir, 'profiles'))..createSync(recursive: true);
      await File(p.join(dir.path, outName)).writeAsBytes(bytes);
      savedUrl = '/uploads/profiles/$outName';
    }
    if (savedUrl == null) return jsonError('이미지 파일을 첨부해주세요.');

    db.execute('UPDATE users SET profile_photo = ? WHERE id = ?', [savedUrl, user['id']]);
    final updated = db.select('SELECT * FROM users WHERE id = ?', [user['id']]).first;
    hub.broadcastStatus();
    return jsonResponse({'user': publicUser(updated)});
  }));

  router.patch('/me/password', withAuth(db, jwtSecret, (request, user) async {
    final body = await readJsonBody(request);
    final currentPassword = body['currentPassword']?.toString();
    final newPassword = body['newPassword']?.toString();
    if (currentPassword == null || currentPassword.isEmpty || newPassword == null || newPassword.isEmpty) {
      return jsonError('현재 비밀번호와 새 비밀번호를 모두 입력해주세요.');
    }
    if (!BCrypt.checkpw(currentPassword, user['password_hash'] as String)) {
      return jsonError('현재 비밀번호가 일치하지 않습니다.', status: 401);
    }
    if (newPassword.length < 4) {
      return jsonError('새 비밀번호는 4자 이상이어야 합니다.');
    }
    final hash = BCrypt.hashpw(newPassword, BCrypt.gensalt());
    db.execute('UPDATE users SET password_hash = ? WHERE id = ?', [hash, user['id']]);
    return Response(204);
  }));

  router.patch('/me/username', withAuth(db, jwtSecret, (request, user) async {
    final body = await readJsonBody(request);
    final password = body['password']?.toString();
    final newUsername = body['newUsername']?.toString().trim();
    if (password == null || password.isEmpty || newUsername == null || newUsername.isEmpty) {
      return jsonError('비밀번호와 새 아이디를 입력해주세요.');
    }
    if (!BCrypt.checkpw(password, user['password_hash'] as String)) {
      return jsonError('비밀번호가 일치하지 않습니다.', status: 401);
    }
    final existing = db.select('SELECT id FROM users WHERE username = ? AND id != ?', [newUsername, user['id']]);
    if (existing.isNotEmpty) return jsonError('이미 사용 중인 아이디입니다.', status: 409);

    db.execute('UPDATE users SET username = ? WHERE id = ?', [newUsername, user['id']]);
    final updated = db.select('SELECT * FROM users WHERE id = ?', [user['id']]).first;
    return jsonResponse({'user': publicUser(updated)});
  }));

  router.post('/me/device-token', withAuth(db, jwtSecret, (request, user) async {
    final body = await readJsonBody(request);
    final token = body['token']?.toString();
    final platform = body['platform']?.toString() ?? 'android';
    if (token == null || token.isEmpty) return jsonError('기기 토큰이 필요합니다.');

    db.execute(
      '''INSERT INTO device_tokens (user_id, token, platform, created_at) VALUES (?, ?, ?, ?)
         ON CONFLICT(token) DO UPDATE SET user_id = excluded.user_id, platform = excluded.platform''',
      [user['id'], token, platform, ServerTime.nowIso()],
    );
    return Response(204);
  }));

  router.delete('/me', withAuth(db, jwtSecret, (request, user) async {
    if ((user['is_admin'] as int) != 0) {
      return jsonError(
        '관리자 계정은 탈퇴할 수 없습니다. 다른 사용자에게 관리자 권한을 넘기는 기능은 아직 지원되지 않습니다.',
        status: 403,
      );
    }
    final body = await readJsonBody(request);
    final password = body['password']?.toString();
    if (password == null || !BCrypt.checkpw(password, user['password_hash'] as String)) {
      return jsonError('비밀번호가 일치하지 않습니다.', status: 401);
    }

    final photo = user['profile_photo'] as String?;
    if (photo != null && photo.startsWith('/uploads/')) {
      final file = File(p.join(uploadsDir, photo.substring('/uploads/'.length)));
      if (await file.exists()) await file.delete();
    }

    db.execute('DELETE FROM users WHERE id = ?', [user['id']]);
    hub.broadcastStatus();
    return Response(204);
  }));

  return router;
}
