import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// 백업 서버가 실행 중인 동안 Android가 프로세스를 정리하지 못하도록 붙잡아
/// 두는 역할만 한다. 실제 HTTP 서버(FamilServer)는 메인 isolate에서 그대로
/// 돌아가므로, 이 핸들러는 알림을 유지하는 것 외에는 할 일이 없다.
@pragma('vm:entry-point')
void backupServerTaskStartCallback() {
  FlutterForegroundTask.setTaskHandler(_BackupServerTaskHandler());
}

class _BackupServerTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
