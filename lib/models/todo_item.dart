import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory TodoItem.fromMap(String id, Map<String, dynamic> map) {
    return TodoItem(
      id: id,
      uid: map['uid'] as String? ?? '',
      text: map['text'] as String? ?? '',
      done: map['done'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      doneAt: (map['doneAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'text': text,
      'done': done,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'doneAt': doneAt != null ? Timestamp.fromDate(doneAt!) : null,
    };
  }
}
