import '../models/alarm.dart';
import 'api_client.dart';
import 'live_query.dart';

class AlarmRepository {
  AlarmRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  Stream<List<Alarm>> watchMyAlarms(String uid) {
    return watchLive(
      fetch: () async {
        final res = await _api.get('/alarms');
        final list = (res['alarms'] as List)
            .map((e) => Alarm.fromJson(e as Map<String, dynamic>))
            .toList();
        list.sort((a, b) =>
            (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
        return list;
      },
      event: 'alarms:changed',
    );
  }

  Future<void> addAlarm(Alarm alarm) {
    return _api.post('/alarms', body: alarm.toJson());
  }

  Future<void> updateAlarm(Alarm alarm) {
    return _api.put('/alarms/${alarm.id}', body: alarm.toJson());
  }

  Future<void> setEnabled(String id, bool enabled) {
    return _api.patch('/alarms/$id', body: {'enabled': enabled});
  }

  Future<void> deleteAlarm(String id) {
    return _api.delete('/alarms/$id');
  }
}
