import '../models/knock.dart';
import 'api_client.dart';
import 'live_query.dart';

class KnockRepository {
  KnockRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  /// 요청자가 방을 노크하면 소유자에게 전달될 알림을 생성한다.
  /// (roomName/requesterUid/requesterName/ownerUid는 화면 호출부 호환을 위해
  /// 남겨두었으나, 실제 값은 서버가 roomId로 조회해 채운다.)
  Future<void> sendKnock({
    required String roomId,
    required String roomName,
    required String requesterUid,
    required String requesterName,
    required String ownerUid,
  }) {
    return _api.post('/knocks', body: {'roomId': roomId});
  }

  /// 소유자에게 온 대기 중인 노크 목록(실시간 알림용).
  Stream<List<Knock>> watchIncomingKnocks(String ownerUid) {
    return watchLive(
      fetch: () async {
        final res = await _api.get('/knocks/incoming');
        return (res['knocks'] as List)
            .map((e) => Knock.fromJson(e as Map<String, dynamic>))
            .toList();
      },
      event: 'knocks:changed',
    );
  }

  /// 요청자에게 온 응답(승인/거절) 중 아직 확인하지 않은 알림.
  Stream<List<Knock>> watchMyResponses(String requesterUid) {
    return watchLive(
      fetch: () async {
        final res = await _api.get('/knocks/responses');
        return (res['knocks'] as List)
            .map((e) => Knock.fromJson(e as Map<String, dynamic>))
            .toList();
      },
      event: 'knocks:changed',
    );
  }

  Future<void> respond(String knockId, {required bool approve}) {
    return _api.patch('/knocks/$knockId/respond', body: {'approve': approve});
  }

  Future<void> acknowledge(String knockId) {
    return _api.patch('/knocks/$knockId/acknowledge');
  }
}
