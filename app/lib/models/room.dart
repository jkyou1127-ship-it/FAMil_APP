class Room {
  final int id;
  final String name;
  final int? ownerId;
  final String accessStatus; // 'open' | 'closed'
  final bool knockEnabled;
  final String createdAt;

  Room({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.accessStatus,
    required this.knockEnabled,
    required this.createdAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: json['id'] as int,
        name: json['name'] as String,
        ownerId: json['ownerId'] as int?,
        accessStatus: json['accessStatus'] as String? ?? 'open',
        knockEnabled: json['knockEnabled'] as bool? ?? true,
        createdAt: json['createdAt'] as String? ?? '',
      );
}
