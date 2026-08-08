import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:sqlite3/sqlite3.dart';

import '../utils/jwt.dart';
import 'realtime_hub.dart';

/// `/realtime?token=<jwt>` 로 들어오는 WebSocket 업그레이드 요청을 처리한다.
/// 소켓 프레임을 실제로 주고받기 전에 토큰을 검증해, 인증되지 않은 연결은
/// 업그레이드 자체를 거부한다 (Socket.IO의 `io.use(...)` 핸드셰이크 인증과 동등).
Handler buildRealtimeHandler(Database db, String jwtSecret, RealtimeHub hub) {
  return (Request request) {
    final token = request.url.queryParameters['token'];
    if (token == null || token.isEmpty) {
      return Response.forbidden('missing token');
    }

    final Row user;
    try {
      final payload = Jwt.verify(token, jwtSecret);
      final rows = db.select('SELECT id FROM users WHERE id = ?', [payload['id']]);
      if (rows.isEmpty) return Response.forbidden('invalid user');
      user = rows.first;
    } on JwtException {
      return Response.forbidden('invalid token');
    }

    final userId = user['id'] as int;
    final upgrade = webSocketHandler((webSocket, protocol) {
      hub.handleConnection(userId, webSocket);
    });
    return upgrade(request);
  };
}
