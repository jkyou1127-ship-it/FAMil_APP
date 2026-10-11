import 'package:flutter/foundation.dart';

import '../models/backup_snapshot.dart';
import 'api_client.dart';

enum LocalServerStatus { stopped, starting, running }

/// 웹 브라우저 안에서는 다른 기기가 접속할 수 있는 서버를 띄울 수 없어, 백업
/// 서버 기능 자체가 성립하지 않는다 — 네이티브(Android/Windows) 구현은
/// local_server_controller_io.dart에 있다. 화면 쪽 코드가 플랫폼을 따로
/// 분기하지 않도록, 같은 공개 API를 그대로 제공하되 전부 "지원 안 됨"으로
/// 동작한다.
class LocalServerController extends ChangeNotifier {
  LocalServerStatus get status => LocalServerStatus.stopped;
  String? get error => _error;
  int? get port => null;
  SnapshotMeta? get snapshotMeta => null;
  bool get hasSnapshot => false;

  String? _error;

  Future<void> loadSavedSnapshotMeta() async {}

  Future<void> downloadSnapshot(ApiClient primaryApi) async {
    throw UnsupportedError('웹에서는 백업 서버 기능을 지원하지 않습니다.');
  }

  Future<void> start({required String primaryBaseUrl, String? primaryToken}) async {
    _error = '웹에서는 백업 서버 기능을 지원하지 않습니다.';
    notifyListeners();
  }

  Future<String?> resolveLocalAddress(int port) async => null;

  Future<void> stop() async {}

  Future<MergeResult> mergeBackToPrimary() async {
    throw UnsupportedError('웹에서는 백업 서버 기능을 지원하지 않습니다.');
  }
}
