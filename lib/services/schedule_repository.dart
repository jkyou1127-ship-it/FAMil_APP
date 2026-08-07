import '../models/schedule_item.dart';
import 'api_client.dart';
import 'live_query.dart';

class ScheduleRepository {
  ScheduleRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  Future<List<ScheduleItem>> _fetch({String? uid, String? date}) async {
    final res = await _api.get('/schedules', query: {
      if (uid != null) 'uid': uid,
      if (date != null) 'date': date,
    });
    return (res['schedules'] as List)
        .map((e) => ScheduleItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Stream<List<ScheduleItem>> watchMySchedules(String uid) {
    return watchLive(fetch: () => _fetch(uid: uid), event: 'schedules:changed');
  }

  /// 특정 날짜('yyyy/MM/dd')에 사용자가 가진 일정 (상태창 표시용).
  Stream<List<ScheduleItem>> watchScheduleForDate(String uid, String date) {
    return watchLive(
      fetch: () => _fetch(uid: uid, date: date),
      event: 'schedules:changed',
    );
  }

  Future<void> addSchedule({
    required String uid,
    required String ownerName,
    required String date,
    required String title,
    String? memo,
  }) {
    return _api.post('/schedules', body: {
      'date': date,
      'title': title,
      'memo': memo,
    });
  }

  Future<void> deleteSchedule(String id) {
    return _api.delete('/schedules/$id');
  }
}
