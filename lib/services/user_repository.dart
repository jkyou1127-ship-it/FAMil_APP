import '../models/app_user.dart';
import 'api_client.dart';
import 'live_query.dart';

class UserRepository {
  UserRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  Future<List<AppUser>> fetchAllUsersOnce() async {
    final res = await _api.get('/users');
    return (res['users'] as List)
        .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 상태창에 표시할 전체 사용자 목록(실시간).
  Stream<List<AppUser>> watchAllUsers() {
    return watchLive(fetch: fetchAllUsersOnce, event: 'users:changed');
  }

  /// 출입 가능/불가능 상태 변경. 불가능으로 바꾸면 온라인 노크가 비활성화된다.
  /// (uid 인자는 화면 호출부 호환을 위해 유지하며, 실제로는 로그인한 본인에게 적용된다.)
  Future<void> setAccessOpen(String uid, bool open) {
    return _api.patch('/users/me', body: {'accessOpen': open});
  }

  Future<void> setSleeping(
    String uid, {
    required bool sleeping,
    DateTime? sleepStartedAt,
  }) {
    return _api.patch('/users/me', body: {
      'isSleeping': sleeping,
      'sleepStartedAt': sleepStartedAt?.toUtc().toIso8601String(),
    });
  }

  Future<void> setSleepMusicEnabled(String uid, bool enabled) {
    return _api.patch('/users/me', body: {'sleepMusicEnabled': enabled});
  }

  Future<void> setDisplayName(String uid, String name) {
    return _api.patch('/users/me', body: {'displayName': name});
  }

  Future<void> setProfilePhotoUrl(String uid, String? url) {
    return _api.patch('/users/me', body: {'profilePhotoUrl': url});
  }
}
