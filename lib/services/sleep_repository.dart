import '../models/sleep_session.dart';
import 'api_client.dart';
import 'live_query.dart';

class SleepRepository {
  SleepRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  Stream<List<SleepSession>> watchMySessions(String uid) {
    return watchLive(
      fetch: () async {
        final res = await _api.get('/sleep-sessions');
        return (res['sessions'] as List)
            .map((e) => SleepSession.fromJson(e as Map<String, dynamic>))
            .toList();
      },
      event: 'sleep:changed',
    );
  }

  Future<void> saveSession({
    required String uid,
    required DateTime sleptAt,
    required DateTime wokeAt,
  }) {
    return _api.post('/sleep-sessions', body: {
      'sleptAt': sleptAt.toUtc().toIso8601String(),
      'wokeAt': wokeAt.toUtc().toIso8601String(),
    });
  }
}
