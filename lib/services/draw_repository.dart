import '../models/draw_event.dart';
import 'api_client.dart';
import 'live_query.dart';

class DrawRepository {
  DrawRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  Stream<List<DrawEvent>> watchHistory() {
    return watchLive(
      fetch: () async {
        final res = await _api.get('/draws');
        return (res['draws'] as List)
            .map((e) => DrawEvent.fromJson(e as Map<String, dynamic>))
            .toList();
      },
      event: 'draws:changed',
    );
  }

  Future<void> saveDraw(DrawEvent event) {
    return _api.post('/draws', body: event.toJson());
  }
}
