import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/backend_mode.dart';
import 'firebase_backend.dart';

/// 로컬 서버가 응답하는지 짧은 타임아웃으로 확인해서, 안 되면 Firebase로
/// 넘어가는 자동 전환을 담당한다. PC가 꺼져 있거나 같은 Wi-Fi가 아니면
/// 헬스체크가 실패하므로, "꺼져 있을 때"와 "다른 네트워크일 때"를 같은
/// 메커니즘 하나로 함께 처리한다.
class BackendModeController extends ChangeNotifier {
  final FirebaseBackend firebaseBackend;
  BackendModeController({required this.firebaseBackend});

  BackendMode mode = BackendMode.local;

  Future<BackendMode> resolve(String localBaseUrl) async {
    final healthy = await _checkLocalHealthy(localBaseUrl);
    if (healthy) {
      mode = BackendMode.local;
    } else {
      final firebaseOk = await firebaseBackend.ensureInitialized();
      mode = firebaseOk ? BackendMode.firebase : BackendMode.local;
    }
    notifyListeners();
    return mode;
  }

  Future<bool> _checkLocalHealthy(String baseUrl) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
      ));
      final res = await dio.get('$baseUrl/health');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
