class TodoItem {
  final int id;
  final String content;
  final bool completed;
  final String? completedDate;
  final String createdAt;

  TodoItem({
    required this.id,
    required this.content,
    required this.completed,
    required this.completedDate,
    required this.createdAt,
  });

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
        id: json['id'] as int,
        content: json['content'] as String,
        completed: json['completed'] as bool,
        completedDate: json['completedDate'] as String?,
        createdAt: json['createdAt'] as String? ?? '',
      );
}
