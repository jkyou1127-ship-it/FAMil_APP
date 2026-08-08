class ShoppingItem {
  final int id;
  final String content;
  final bool bought;
  final int addedBy;
  final String addedByName;
  final int? boughtBy;
  final String? boughtByName;
  final String createdAt;
  final String? boughtAt;

  ShoppingItem({
    required this.id,
    required this.content,
    required this.bought,
    required this.addedBy,
    required this.addedByName,
    required this.boughtBy,
    required this.boughtByName,
    required this.createdAt,
    required this.boughtAt,
  });

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
        id: json['id'] as int,
        content: json['content'] as String,
        bought: json['bought'] as bool,
        addedBy: json['addedBy'] as int,
        addedByName: json['addedByName'] as String? ?? '',
        boughtBy: json['boughtBy'] as int?,
        boughtByName: json['boughtByName'] as String?,
        createdAt: json['createdAt'] as String,
        boughtAt: json['boughtAt'] as String?,
      );
}
