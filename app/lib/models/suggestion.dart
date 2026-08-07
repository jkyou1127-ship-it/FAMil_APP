class Suggestion {
  final int id;
  final String content;
  final String createdAt;

  Suggestion({required this.id, required this.content, required this.createdAt});

  factory Suggestion.fromJson(Map<String, dynamic> json) => Suggestion(
        id: json['id'] as int,
        content: json['content'] as String,
        createdAt: json['createdAt'] as String,
      );
}
