import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/sleep_session.dart';

class SleepRepository {
  SleepRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('sleepSessions');

  Stream<List<SleepSession>> watchMySessions(String uid) {
    return _sessions
        .where('uid', isEqualTo: uid)
        .orderBy('wokeAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SleepSession.fromMap(d.id, d.data()))
            .toList());
  }

  Future<void> saveSession({
    required String uid,
    required DateTime sleptAt,
    required DateTime wokeAt,
  }) {
    return _sessions.add(SleepSession(
      id: '',
      uid: uid,
      sleptAt: sleptAt,
      wokeAt: wokeAt,
    ).toMap());
  }
}
