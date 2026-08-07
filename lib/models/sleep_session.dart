import 'package:cloud_firestore/cloud_firestore.dart';

/// 취침~기상 세션 이력 (잔 시간 계산용).
class SleepSession {
  final String id;
  final String uid;
  final DateTime sleptAt;
  final DateTime wokeAt;

  const SleepSession({
    required this.id,
    required this.uid,
    required this.sleptAt,
    required this.wokeAt,
  });

  Duration get duration => wokeAt.difference(sleptAt);

  factory SleepSession.fromMap(String id, Map<String, dynamic> map) {
    return SleepSession(
      id: id,
      uid: map['uid'] as String? ?? '',
      sleptAt: (map['sleptAt'] as Timestamp).toDate(),
      wokeAt: (map['wokeAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'sleptAt': Timestamp.fromDate(sleptAt),
      'wokeAt': Timestamp.fromDate(wokeAt),
      'durationMinutes': duration.inMinutes,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
