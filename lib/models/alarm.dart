enum AlarmRepeat { daily, weekly, once }

AlarmRepeat alarmRepeatFromString(String value) {
  return AlarmRepeat.values.firstWhere(
    (r) => r.name == value,
    orElse: () => AlarmRepeat.once,
  );
}

/// 알람: 매일 / 요일별 / 특정 날짜에 지정한 시각에 울린다.
class Alarm {
  final String id;
  final String uid;
  final String label;
  final int hour; // 0-23 (KST 기준)
  final int minute; // 0-59
  final AlarmRepeat repeat;

  /// repeat == weekly 일 때 사용. 1(월) ~ 7(일), Dart DateTime.weekday와 동일.
  final Set<int> weekdays;

  /// repeat == once 일 때 사용. 'yyyy/MM/dd' 형식.
  final String? onceDate;

  /// 내장 알람음 id (SoundLibrary.alarmSounds 참고) 또는 사용자가 직접 선택한
  /// 파일 경로([customSoundPath]가 있으면 우선 사용).
  final String soundId;
  final String? customSoundPath;

  final bool enabled;

  const Alarm({
    required this.id,
    required this.uid,
    required this.label,
    required this.hour,
    required this.minute,
    this.repeat = AlarmRepeat.once,
    this.weekdays = const {},
    this.onceDate,
    this.soundId = 'alarm_classic',
    this.customSoundPath,
    this.enabled = true,
  });

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  factory Alarm.fromMap(String id, Map<String, dynamic> map) {
    return Alarm(
      id: id,
      uid: map['uid'] as String? ?? '',
      label: map['label'] as String? ?? '알람',
      hour: map['hour'] as int? ?? 7,
      minute: map['minute'] as int? ?? 0,
      repeat: alarmRepeatFromString(map['repeat'] as String? ?? 'once'),
      weekdays: Set<int>.from(
          (map['weekdays'] as List?)?.map((e) => e as int) ?? const []),
      onceDate: map['onceDate'] as String?,
      soundId: map['soundId'] as String? ?? 'alarm_classic',
      customSoundPath: map['customSoundPath'] as String?,
      enabled: map['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'label': label,
      'hour': hour,
      'minute': minute,
      'repeat': repeat.name,
      'weekdays': weekdays.toList(),
      'onceDate': onceDate,
      'soundId': soundId,
      'customSoundPath': customSoundPath,
      'enabled': enabled,
    };
  }
}
