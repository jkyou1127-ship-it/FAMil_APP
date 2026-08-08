import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

/// REST API 호출을 담당하는 얇은 Dio 래퍼.
/// 서버 주소와 로그인 토큰은 앱 실행 중에 바뀔 수 있어 인스턴스 메서드로 갱신한다.
class ApiClient {
  late final Dio dio;
  String baseUrl;

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

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _wrap(() => dio.get(path, queryParameters: query));

  Future<Map<String, dynamic>> post(String path, [dynamic data]) =>
      _wrap(() => dio.post(path, data: data));

  Future<Map<String, dynamic>> patch(String path, [dynamic data]) =>
      _wrap(() => dio.patch(path, data: data));

  Future<void> delete(String path, [dynamic data]) =>
      _wrap(() => dio.delete(path, data: data)).then((_) {});

  Future<Map<String, dynamic>> uploadPhoto(String path, List<int> bytes, String filename) {
    final form = FormData.fromMap({
      'photo': MultipartFile.fromBytes(bytes, filename: filename),
    });
    return _wrap(() => dio.post(path, data: form));
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
