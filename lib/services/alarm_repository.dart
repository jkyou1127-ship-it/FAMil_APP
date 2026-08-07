import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/alarm.dart';

class AlarmRepository {
  AlarmRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _alarms =>
      _db.collection('alarms');

  Stream<List<Alarm>> watchMyAlarms(String uid) {
    return _alarms.where('uid', isEqualTo: uid).snapshots().map((snap) {
      final list =
          snap.docs.map((d) => Alarm.fromMap(d.id, d.data())).toList();
      list.sort((a, b) =>
          (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
      return list;
    });
  }

  Future<void> addAlarm(Alarm alarm) => _alarms.add(alarm.toMap());

  Future<void> updateAlarm(Alarm alarm) =>
      _alarms.doc(alarm.id).update(alarm.toMap());

  Future<void> setEnabled(String id, bool enabled) =>
      _alarms.doc(id).update({'enabled': enabled});

  Future<void> deleteAlarm(String id) => _alarms.doc(id).delete();
}
