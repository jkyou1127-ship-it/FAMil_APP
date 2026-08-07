import '../models/suggestion.dart';
import 'api_client.dart';
import 'live_query.dart';

class SuggestionRepository {
  SuggestionRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  Future<List<Suggestion>> _fetchAll() async {
    final res = await _api.get('/suggestions');
    return (res['suggestions'] as List)
        .map((e) => Suggestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 모두가 볼 수 있는 익명 건의사항 목록(실시간).
  Stream<List<Suggestion>> watchAll() {
    return watchLive(fetch: _fetchAll, event: 'suggestions:changed');
  }

  Future<void> submit(String text) {
    return _api.post('/suggestions', body: {'text': text});
  }
}
