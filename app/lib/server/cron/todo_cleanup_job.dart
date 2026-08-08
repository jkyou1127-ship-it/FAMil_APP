import 'dart:async';

import 'package:sqlite3/sqlite3.dart';

import '../utils/kst_time.dart';

/// backend/src/cron/index.js를 포팅. KST 자정에 완료 후 하루가 지난
/// (전날 이전에 완료된) 할 일을 삭제한다. node-cron 대신, 매분 KST 날짜가
/// 바뀌었는지 확인하는 방식으로 구현했다 (같은 결과, 별도 cron 라이브러리 불필요).
class TodoCleanupJob {
  final Database db;
  Timer? _timer;
  String? _lastDate;

  TodoCleanupJob(this.db);

  void start() {
    _lastDate = ServerTime.kstDateString();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _check());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _check() {
    final today = ServerTime.kstDateString();
    if (today == _lastDate) return;
    _lastDate = today;
    cleanupCompletedTodos();
  }

  void cleanupCompletedTodos() {
    final today = ServerTime.kstDateString();
    db.execute('DELETE FROM todos WHERE completed = 1 AND completed_date < ?', [today]);
  }
}
