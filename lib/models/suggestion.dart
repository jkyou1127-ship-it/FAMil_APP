import 'package:cloud_firestore/cloud_firestore.dart';

/// 건의사항: 익명으로 등록되며 모두가 볼 수 있다.
/// 작성자를 알 수 없도록 uid를 저장하지 않는다.
class Suggestion {
  final String id;
  final String text;
  final DateTime? createdAt;

  const Suggestion({
    required this.id,
    required this.text,
    this.createdAt,
  });

  factory Suggestion.fromMap(String id, Map<String, dynamic> map) {
    return Suggestion(
      id: id,
      text: map['text'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
