class ScheduleItem {
  final int id;
  final String date; // YYYY-MM-DD
  final String content;
  final String createdAt;

  ScheduleItem({
    required this.id,
    required this.date,
    required this.content,
    required this.createdAt,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json) => ScheduleItem(
        id: json['id'] as int,
        date: json['date'] as String,
        content: json['content'] as String,
        createdAt: json['createdAt'] as String? ?? '',
      );
}
