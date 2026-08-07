import '../services/json_time.dart';

class TodoItem {
  final String id;
  final String uid;
  final String text;
  final bool done;
  final DateTime? createdAt;
  final DateTime? doneAt;

  const TodoItem({
    required this.id,
    required this.uid,
    required this.text,
    this.done = false,
    this.createdAt,
    this.doneAt,
  });

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as String,
      uid: json['uid'] as String? ?? '',
      text: json['text'] as String? ?? '',
      done: json['done'] as bool? ?? false,
      createdAt: parseTime(json['createdAt']),
      doneAt: parseTime(json['doneAt']),
    );
  }
}
