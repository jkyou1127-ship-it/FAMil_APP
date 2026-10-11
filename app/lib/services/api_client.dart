import 'package:dio/dio.dart';

import '../models/backend_mode.dart';
import 'api_exception.dart';
import 'firebase_backend.dart';

export 'api_exception.dart';

/// REST API 호출을 담당하는 얇은 Dio 래퍼.
/// 서버 주소와 로그인 토큰은 앱 실행 중에 바뀔 수 있어 인스턴스 메서드로 갱신한다.
///
/// mode가 firebase일 때는 로컬 서버가 없으므로 Dio를 쓰지 않는다. 상태창/
/// 매신저처럼 Firestore로 대체 구현된 몇 개 GET 경로만 FirebaseBackend로
/// 넘기고, 나머지는 "지원되지 않음" 오류를 바로 던진다.
class ApiClient {
  late final Dio dio;
  String baseUrl;
  BackendMode mode = BackendMode.local;
  FirebaseBackend? firebaseBackend;

  ApiClient({required this.baseUrl}) {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  void updateBaseUrl(String url) {
    baseUrl = url;
    dio.options.baseUrl = url;
  }

  void setToken(String? token) {
    if (token != null) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      dio.options.headers.remove('Authorization');
    }
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) {
    if (mode == BackendMode.firebase) return _firebaseGet(path);
    return _wrap(() => dio.get(path, queryParameters: query));
  }

  Future<Map<String, dynamic>> post(String path, [dynamic data]) {
    if (mode == BackendMode.firebase) return _unsupportedInFirebaseMode();
    return _wrap(() => dio.post(path, data: data));
  }

  Future<Map<String, dynamic>> patch(String path, [dynamic data]) {
    if (mode == BackendMode.firebase) return _unsupportedInFirebaseMode();
    return _wrap(() => dio.patch(path, data: data));
  }

  Future<void> delete(String path, [dynamic data]) {
    if (mode == BackendMode.firebase) return _unsupportedInFirebaseMode();
    return _wrap(() => dio.delete(path, data: data)).then((_) {});
  }

  Future<Map<String, dynamic>> uploadPhoto(String path, List<int> bytes, String filename) {
    if (mode == BackendMode.firebase) return _unsupportedInFirebaseMode();
    final form = FormData.fromMap({
      'photo': MultipartFile.fromBytes(bytes, filename: filename),
    });
    return _wrap(() => dio.post(path, data: form));
  }

  Future<Map<String, dynamic>> _firebaseGet(String path) {
    final fb = firebaseBackend;
    if (fb == null) return _unsupportedInFirebaseMode();
    if (path == '/users') return fb.fetchUsersJson();
    if (path == '/status') return fb.fetchStatusBoardJson();
    if (path == '/messages/conversations') return fb.fetchConversationsJson();
    final match = RegExp(r'^/messages/(\d+)$').firstMatch(path);
    if (match != null) return fb.fetchDirectMessagesJson(int.parse(match.group(1)!));
    return _unsupportedInFirebaseMode();
  }

  Future<Map<String, dynamic>> _unsupportedInFirebaseMode() {
    throw ApiException('Firebase 모드에서는 지원되지 않는 기능입니다. PC 서버가 켜져 있고 같은 Wi-Fi에 연결되면 모든 기능을 다시 쓸 수 있어요.');
  }

  Future<Map<String, dynamic>> _wrap(Future<Response> Function() call) async {
    try {
      final res = await call();
      if (res.data is Map<String, dynamic>) return res.data as Map<String, dynamic>;
      return <String, dynamic>{};
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : (e.message ?? '네트워크 오류가 발생했습니다.');
      throw ApiException(msg, e.response?.statusCode);
    }
  }
}
