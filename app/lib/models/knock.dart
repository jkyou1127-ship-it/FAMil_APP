class Knock {
  final int id;
  final int roomId;
  final String roomName;
  final int requesterId;
  final String requesterName;
  final String status; // 'pending' | 'approved' | 'denied'
  final String createdAt;
  final String? respondedAt;

  Knock({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.requesterId,
    required this.requesterName,
    required this.status,
    required this.createdAt,
    required this.respondedAt,
  });

  factory Knock.fromJson(Map<String, dynamic> json) => Knock(
        id: json['id'] as int,
        roomId: json['roomId'] as int,
        roomName: json['roomName'] as String? ?? '',
        requesterId: json['requesterId'] as int,
        requesterName: json['requesterName'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        createdAt: json['createdAt'] as String? ?? '',
        respondedAt: json['respondedAt'] as String?,
      );
}
