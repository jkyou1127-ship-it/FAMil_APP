import '../services/json_time.dart';

/// 일정: 특정 날(년/월/일)에 해야 할 일을 알려주는 항목.
class ScheduleItem {
  final String id;
  final String uid;
  final String ownerName;

  /// 'yyyy/MM/dd' 형식의 날짜 (한국 표준시 기준).
  final String date;
  final String title;
  final String? memo;
  final DateTime? createdAt;

  const ScheduleItem({
    required this.id,
    required this.uid,
    required this.ownerName,
    required this.date,
    required this.title,
    this.memo,
    this.createdAt,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      id: json['id'] as String,
      uid: json['uid'] as String? ?? '',
      ownerName: json['ownerName'] as String? ?? '',
      date: json['date'] as String? ?? '',
      title: json['title'] as String? ?? '',
      memo: json['memo'] as String?,
      createdAt: parseTime(json['createdAt']),
    );
  }
}
