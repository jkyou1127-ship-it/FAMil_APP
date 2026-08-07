import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/schedule_item.dart';

class ScheduleRepository {
  ScheduleRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _schedules =>
      _db.collection('schedules');

  Stream<List<ScheduleItem>> watchMySchedules(String uid) {
    return _schedules
        .where('uid', isEqualTo: uid)
        .orderBy('date')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ScheduleItem.fromMap(d.id, d.data()))
            .toList());
  }

  /// 특정 날짜('yyyy/MM/dd')에 사용자가 가진 일정 (상태창 표시용).
  Stream<List<ScheduleItem>> watchScheduleForDate(String uid, String date) {
    return _schedules
        .where('uid', isEqualTo: uid)
        .where('date', isEqualTo: date)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ScheduleItem.fromMap(d.id, d.data()))
            .toList());
  }

  Future<void> addSchedule({
    required String uid,
    required String ownerName,
    required String date,
    required String title,
    String? memo,
  }) {
    return _schedules.add(ScheduleItem(
      id: '',
      uid: uid,
      ownerName: ownerName,
      date: date,
      title: title,
      memo: memo,
    ).toMap());
  }

  Future<void> deleteSchedule(String id) {
    return _schedules.doc(id).delete();
  }
}
