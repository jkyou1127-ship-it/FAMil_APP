import '../services/json_time.dart';

enum KnockStatus { pending, approved, denied }

KnockStatus knockStatusFromString(String value) {
  return KnockStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => KnockStatus.pending,
  );
}

/// 온라인 노크: 요청자가 소유자의 방을 노크하면 생성되고,
/// 소유자가 승인/거절하면 요청자에게 알림이 간다.
class Knock {
  final String id;
  final String roomId;
  final String roomName;
  final String requesterUid;
  final String requesterName;
  final String ownerUid;
  final KnockStatus status;
  final DateTime? createdAt;
  final DateTime? respondedAt;

  /// 요청자가 응답(승인/거절) 알림을 확인했는지 여부.
  final bool requesterAcknowledged;

  const Knock({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.requesterUid,
    required this.requesterName,
    required this.ownerUid,
    this.status = KnockStatus.pending,
    this.createdAt,
    this.respondedAt,
    this.requesterAcknowledged = false,
  });

  factory Knock.fromJson(Map<String, dynamic> json) {
    return Knock(
      id: json['id'] as String,
      roomId: json['roomId'] as String? ?? '',
      roomName: json['roomName'] as String? ?? '',
      requesterUid: json['requesterUid'] as String? ?? '',
      requesterName: json['requesterName'] as String? ?? '',
      ownerUid: json['ownerUid'] as String? ?? '',
      status: knockStatusFromString(json['status'] as String? ?? 'pending'),
      createdAt: parseTime(json['createdAt']),
      respondedAt: parseTime(json['respondedAt']),
      requesterAcknowledged: json['requesterAcknowledged'] as bool? ?? false,
    );
  }
}
