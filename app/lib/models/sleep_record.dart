class SleepRecord {
  final int id;
  final String sleepAt;
  final String? wakeAt;
  final int? durationMinutes;

  SleepRecord({
    required this.id,
    required this.sleepAt,
    required this.wakeAt,
    required this.durationMinutes,
  });

  factory SleepRecord.fromJson(Map<String, dynamic> json) => SleepRecord(
        id: json['id'] as int,
        sleepAt: json['sleepAt'] as String,
        wakeAt: json['wakeAt'] as String?,
        durationMinutes: json['durationMinutes'] as int?,
      );
}
