import '../services/json_time.dart';

/// 건의사항: 익명으로 등록되며 모두가 볼 수 있다.
/// 작성자를 알 수 없도록 서버에도 uid를 저장하지 않는다.
class Suggestion {
  final String id;
  final String text;
  final DateTime? createdAt;

  const Suggestion({
    required this.id,
    required this.text,
    this.createdAt,
  });

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    return Suggestion(
      id: json['id'] as String,
      text: json['text'] as String? ?? '',
      createdAt: parseTime(json['createdAt']),
    );
  }
}
