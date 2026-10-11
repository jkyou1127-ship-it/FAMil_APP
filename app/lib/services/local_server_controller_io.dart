import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/backup_snapshot.dart';
import '../server/backup_merge_export.dart';
import '../server/discovery_responder.dart';
import '../server/famil_server.dart';
import 'api_client.dart';
import 'backup_server_task_handler.dart';

enum LocalServerStatus { stopped, starting, running }

/// PC 서버가 꺼졌을 때 이 기기(폰/PC)를 같은 Wi-Fi 안에서만 쓰는 임시 백업
/// 서버로 켤 수 있게 해준다. 인터넷 전체에 노출되는 것이 아니라 어디까지나
/// 집 안에서의 임시 대체 용도다.
///
/// 자동으로 주 서버 자리를 "빼앗는" 방식(자동 장애조치)이 아니라, 사용자가
/// 직접 시작/복귀 버튼을 눌러야 동작한다 — 여러 기기가 동시에 백업 서버로
/// 켜져 서로 다른 데이터를 만드는 상황(split-brain)을 피하기 위한 선택이다.
class LocalServerController extends ChangeNotifier {
  static const _prefsJwtSecretKey = 'local_server_jwt_secret';

  FamilServer? _server;
  RawDatagramSocket? _discoverySocket;
  bool _starting = false;
  String? _error;
  String? _primaryBaseUrl;
  String? _primaryToken;
  SnapshotMeta? _snapshotMeta;

  LocalServerStatus get status =>
      _starting ? LocalServerStatus.starting : (_server != null ? LocalServerStatus.running : LocalServerStatus.stopped);
  String? get error => _error;
  int? get port => _server?.port;
  SnapshotMeta? get snapshotMeta => _snapshotMeta;
  bool get hasSnapshot => _snapshotMeta != null;

  Future<Directory> _baseDir() async {
    final dir = await getApplicationSupportDirectory();
    final target = Directory(p.join(dir.path, 'famil_backup_server'));
    await target.create(recursive: true);
    return target;
  }

  Future<String> _snapshotPath() async => p.join((await _baseDir()).path, 'snapshot.db');
  Future<String> _activePath() async => p.join((await _baseDir()).path, 'active.db');
  Future<String> _metaPath() async => p.join((await _baseDir()).path, 'snapshot_meta.json');
  Future<String> _uploadsPath() async => p.join((await _baseDir()).path, 'uploads');

  Future<String> _localJwtSecret() async {
    final prefs = await SharedPreferences.getInstance();
    var secret = prefs.getString(_prefsJwtSecretKey);
    if (secret == null) {
      final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
      secret = base64Url.encode(bytes);
      await prefs.setString(_prefsJwtSecretKey, secret);
    }
    return secret;
  }

  /// 저장된 스냅샷 메타데이터(있다면)를 불러온다. 앱 시작 시 화면에 "마지막
  /// 스냅샷: N분 전" 같은 상태를 보여주기 위해 호출한다.
  Future<void> loadSavedSnapshotMeta() async {
    final metaFile = File(await _metaPath());
    if (!await metaFile.exists()) return;
    try {
      final map = json.decode(await metaFile.readAsString()) as Map<String, dynamic>;
      _snapshotMeta = SnapshotMeta.fromJson(map);
      notifyListeners();
    } catch (_) {
      // 손상된 메타 파일은 무시한다 (다음 스냅샷 저장 시 덮어써진다).
    }
  }

  /// 주 서버(현재 연결되어 있는 서버)에서 DB 스냅샷을 받아 로컬에 저장한다.
  /// [primaryApi]는 아직 주 서버를 가리키고 있는 상태의 ApiClient여야 한다.
  Future<void> downloadSnapshot(ApiClient primaryApi) async {
    final metaJson = await primaryApi.get('/backup/meta');
    final response = await primaryApi.dio.get<List<int>>(
      '/backup/snapshot',
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null) throw StateError('스냅샷 응답이 비어 있습니다.');

    await File(await _snapshotPath()).writeAsBytes(bytes, flush: true);
    await File(await _metaPath()).writeAsString(json.encode(metaJson), flush: true);
    _snapshotMeta = SnapshotMeta.fromJson(metaJson);
    notifyListeners();
  }

  /// 백업 서버를 시작한다. [primaryBaseUrl]/[primaryToken]은 나중에 "주 서버로
  /// 복귀"할 때 새로 생긴 데이터를 되돌려 보낼 대상으로 기억해둔다.
  Future<void> start({required String primaryBaseUrl, String? primaryToken}) async {
    if (_server != null || _starting) return;
    _starting = true;
    _error = null;
    notifyListeners();
    try {
      final snapshotFile = File(await _snapshotPath());
      final activePath = await _activePath();
      final activeFile = File(activePath);
      if (await snapshotFile.exists()) {
        await snapshotFile.copy(activePath);
      } else if (await activeFile.exists()) {
        await activeFile.delete();
      }

      final jwtSecret = await _localJwtSecret();
      final server = FamilServer.open(dbPath: activePath, jwtSecret: jwtSecret, uploadsDir: await _uploadsPath());
      await server.start(port: 4000);
      _discoverySocket = await startUdpDiscoveryResponder(server.port!);
      _server = server;
      _primaryBaseUrl = primaryBaseUrl;
      _primaryToken = primaryToken;

      if (defaultTargetPlatform == TargetPlatform.android) {
        await _startAndroidForegroundService();
      }
    } catch (e) {
      _error = e.toString();
      await _server?.stop();
      _server = null;
    } finally {
      _starting = false;
      notifyListeners();
    }
  }

  /// 이 기기의 같은 Wi-Fi 상 사설 IP 주소를 추정한다 (화면에 안내 문구로 보여주는 용도 —
  /// 못 찾아도 서버 자체는 계속 동작하고, 자동 감지로는 여전히 찾을 수 있다).
  Future<String?> resolveLocalAddress(int port) async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('169.254')) {
            return 'http://${addr.address}:$port';
          }
        }
      }
    } catch (_) {
      // 위 설명대로 실패해도 무시한다.
    }
    return null;
  }

  Future<void> _startAndroidForegroundService() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'famil_backup_server',
        channelName: 'FAMil 백업 서버',
        channelDescription: '이 기기가 임시 백업 서버로 동작하는 동안 표시됩니다.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
      ),
    );
    await FlutterForegroundTask.startService(
      serviceTypes: const [ForegroundServiceTypes.dataSync],
      notificationTitle: 'FAMil 백업 서버 실행 중',
      notificationText: '같은 Wi-Fi의 가족 기기가 이 기기로 접속할 수 있습니다.',
      callback: backupServerTaskStartCallback,
    );
  }

  /// 백업 서버를 중지한다. 병합을 먼저 하고 싶다면 [mergeBackToPrimary]를
  /// 먼저 호출한 뒤 이 메서드를 호출해야 한다.
  Future<void> stop() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await FlutterForegroundTask.stopService();
    }
    _discoverySocket?.close();
    _discoverySocket = null;
    await _server?.stop();
    _server = null;
    _primaryBaseUrl = null;
    _primaryToken = null;
    notifyListeners();
  }

  /// 백업 서버로 동작하는 동안 새로 생긴 데이터를 주 서버로 되돌려 보낸다.
  /// 서버가 실행 중이어야 하고, [start]에서 기억해둔 주 서버 주소가 필요하다.
  Future<MergeResult> mergeBackToPrimary() async {
    final server = _server;
    final baseUrl = _primaryBaseUrl;
    final meta = _snapshotMeta;
    if (server == null || baseUrl == null) {
      throw StateError('백업 서버가 실행 중이 아니거나 주 서버 주소를 알 수 없습니다.');
    }
    if (meta == null) {
      throw StateError('스냅샷 기준 정보가 없어 어떤 데이터가 새로 생겼는지 알 수 없습니다.');
    }

    final rows = exportNewRowsForMerge(server.db, meta);
    final dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 10)));
    if (_primaryToken != null) {
      dio.options.headers['Authorization'] = 'Bearer $_primaryToken';
    }
    final res = await dio.post('/backup/merge-import', data: rows);
    return MergeResult.fromJson(Map<String, dynamic>.from(res.data as Map));
  }
}
