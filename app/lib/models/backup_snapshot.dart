/// 백업 스냅샷을 내려받은 시점의 기준값. 이 시점 이전부터 있던 사용자/방/
/// 단톡방을 참조하는 데이터만 나중에 주 서버로 안전하게 병합할 수 있다.
class SnapshotMeta {
  final DateTime takenAt;
  final int maxUserId;
  final int maxRoomId;
  final int maxChatRoomId;

  SnapshotMeta({
    required this.takenAt,
    required this.maxUserId,
    required this.maxRoomId,
    required this.maxChatRoomId,
  });

  factory SnapshotMeta.fromJson(Map<String, dynamic> json) => SnapshotMeta(
        takenAt: DateTime.parse(json['takenAt'] as String),
        maxUserId: json['maxUserId'] as int,
        maxRoomId: json['maxRoomId'] as int,
        maxChatRoomId: json['maxChatRoomId'] as int,
      );

  Map<String, dynamic> toJson() => {
        'takenAt': takenAt.toIso8601String(),
        'maxUserId': maxUserId,
        'maxRoomId': maxRoomId,
        'maxChatRoomId': maxChatRoomId,
      };
}

class MergeResult {
  final Map<String, int> imported;
  final int skipped;

  MergeResult({required this.imported, required this.skipped});

  factory MergeResult.fromJson(Map<String, dynamic> json) => MergeResult(
        imported: Map<String, int>.from(json['imported'] as Map),
        skipped: json['skipped'] as int,
      );

  int get totalImported => imported.values.fold(0, (a, b) => a + b);
}
