import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:sqlite3/sqlite3.dart';

import 'cron/todo_cleanup_job.dart';
import 'db/schema.dart';
import 'realtime/realtime_hub.dart';
import 'realtime/ws_route.dart';
import 'routes/alarms_routes.dart';
import 'routes/auth_routes.dart';
import 'routes/messages_routes.dart';
import 'routes/rooms_routes.dart';
import 'routes/schedules_routes.dart';
import 'routes/sleep_routes.dart';
import 'routes/status_routes.dart';
import 'routes/suggestions_routes.dart';
import 'routes/todos_routes.dart';
import 'routes/users_routes.dart';
import 'utils/json_response.dart';
import 'utils/kst_time.dart';

/// Windows/Android 앱에 내장되어 backend/의 Node.js 서버와 동일한 REST API를
/// 제공하는 서버. 두 백엔드가 같은 SQLite 스키마와 API 계약을 쓰기 때문에,
/// 어느 쪽이 host 역할을 하든 클라이언트는 동일하게 동작한다.
class FamilServer {
  final Database db;
  final String jwtSecret;
  final String uploadsDir;
  final RealtimeHub realtime;
  final TodoCleanupJob _todoCleanup;
  HttpServer? _httpServer;

  FamilServer._(this.db, this.jwtSecret, this.uploadsDir, this.realtime, this._todoCleanup);

  static FamilServer open({required String dbPath, required String jwtSecret, required String uploadsDir}) {
    ServerTime.init();
    final db = openFamilDatabase(dbPath);
    Directory(uploadsDir).createSync(recursive: true);
    return FamilServer._(db, jwtSecret, uploadsDir, RealtimeHub(db), TodoCleanupJob(db));
  }

  int? get port => _httpServer?.port;

  Future<void> start({int port = 4000, String address = '0.0.0.0'}) async {
    if (_httpServer != null) return;

    final router = Router();
    router.mount('/auth', buildAuthRouter(db, jwtSecret).call);
    router.mount('/users', buildUsersRouter(db, jwtSecret, realtime, uploadsDir: uploadsDir).call);
    router.mount('/rooms', buildRoomsRouter(db, jwtSecret, realtime).call);
    router.mount('/messages', buildMessagesRouter(db, jwtSecret, realtime).call);
    router.mount('/suggestions', buildSuggestionsRouter(db, jwtSecret).call);
    router.mount('/status', buildStatusRouter(db, jwtSecret).call);
    router.mount('/sleep', buildSleepRouter(db, jwtSecret, realtime).call);
    router.mount('/alarms', buildAlarmsRouter(db, jwtSecret).call);
    router.mount('/schedules', buildSchedulesRouter(db, jwtSecret).call);
    router.mount('/todos', buildTodosRouter(db, jwtSecret).call);
    router.mount('/uploads', createStaticHandler(uploadsDir));
    router.get('/health', (Request request) => jsonResponse({'ok': true, 'time': DateTime.now().toUtc().toIso8601String()}));
    router.get('/realtime', buildRealtimeHandler(db, jwtSecret, realtime));

    final handler = const Pipeline().addMiddleware(_corsHeaders()).addHandler(router.call);
    _httpServer = await shelf_io.serve(handler, address, port);
    _todoCleanup.start();
  }

  /// 테스트 전용: 실제로는 KST 자정에 자동 실행되는 정리 작업을 즉시 실행한다.
  void runTodoCleanupForTest() => _todoCleanup.cleanupCompletedTodos();

  Future<void> stop() async {
    _todoCleanup.stop();
    await _httpServer?.close(force: true);
    _httpServer = null;
    db.close();
  }
}

Middleware _corsHeaders() {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };
  return (Handler inner) {
    return (Request request) async {
      if (request.method == 'OPTIONS') return Response.ok('', headers: headers);
      final response = await inner(request);
      return response.change(headers: headers);
    };
  };
}
