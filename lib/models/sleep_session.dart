import '../services/json_time.dart';

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

  factory SleepSession.fromJson(Map<String, dynamic> json) {
    return SleepSession(
      id: json['id'] as String,
      uid: json['uid'] as String? ?? '',
      sleptAt: parseTime(json['sleptAt'])!,
      wokeAt: parseTime(json['wokeAt'])!,
    );
  }
}
