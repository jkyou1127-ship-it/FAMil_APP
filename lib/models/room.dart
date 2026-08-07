class Room {
  final String id;
  final String name;

  /// 방의 소유자(실제로 생활하는 사람) uid. 관리자가 배정한다.
  final String? ownerUid;
  final String? ownerName;

  /// 온라인 노크 시스템 활성화 여부. 소유자가 출입 불가로 바꾸면 false가 된다.
  final bool knockEnabled;

  const Room({
    required this.id,
    required this.name,
    this.ownerUid,
    this.ownerName,
    this.knockEnabled = true,
  });

  factory Room.fromMap(String id, Map<String, dynamic> map) {
    return Room(
      id: id,
      name: map['name'] as String? ?? '',
      ownerUid: map['ownerUid'] as String?,
      ownerName: map['ownerName'] as String?,
      knockEnabled: map['knockEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ownerUid': ownerUid,
      'ownerName': ownerName,
      'knockEnabled': knockEnabled,
    };
  }
}
