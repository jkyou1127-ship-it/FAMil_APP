class Alarm {
  final int id;
  final String? label;
  final String time; // HH:mm
  final String repeatType; // 'once' | 'daily' | 'weekly' | 'date'
  final List<int> repeatDays; // 0=Sun..6=Sat, used when repeatType == 'weekly'
  final String? specificDate; // YYYY-MM-DD
  final String sound;
  final bool enabled;
  final String createdAt;

  Alarm({
    required this.id,
    required this.label,
    required this.time,
    required this.repeatType,
    required this.repeatDays,
    required this.specificDate,
    required this.sound,
    required this.enabled,
    required this.createdAt,
  });

  factory Alarm.fromJson(Map<String, dynamic> json) => Alarm(
        id: json['id'] as int,
        label: json['label'] as String?,
        time: json['time'] as String,
        repeatType: json['repeatType'] as String,
        repeatDays: (json['repeatDays'] as List<dynamic>? ?? []).map((e) => e as int).toList(),
        specificDate: json['specificDate'] as String?,
        sound: json['sound'] as String,
        enabled: json['enabled'] as bool,
        createdAt: json['createdAt'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'time': time,
        'repeatType': repeatType,
        'repeatDays': repeatDays,
        'specificDate': specificDate,
        'sound': sound,
        'enabled': enabled,
      };
}
