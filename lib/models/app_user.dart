import 'package:cloud_firestore/cloud_firestore.dart';

/// 사용자 권한.
/// - admin: 시스템 전체를 관리하는 계정, 딱 1명만 존재한다("첫" 계정이 관리자가 된다).
/// - member: 그 외 일반 사용자. 관리자가 방의 소유자로 배정하면 [roomId]가 채워진다.
enum UserRole { admin, member }

UserRole userRoleFromString(String value) {
  return UserRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => UserRole.member,
  );
}

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;

  /// 관리자가 배정한 방 ID. null이면 아직 어떤 방의 소유자도 아니다.
  final String? roomId;

  /// 접속 상태 (on/off).
  final bool isOnline;

  /// 출입 가능 여부 (소유자가 온라인 노크를 받을지 여부와 연동).
  final bool accessOpen;

  /// 취침 여부.
  final bool isSleeping;
  final DateTime? sleepStartedAt;

  /// 수면유도 노래 재생 여부 설정. off로 바꾸면 다시 on으로 바꾸기 전까지 유지된다.
  final bool sleepMusicEnabled;

  final String? profilePhotoUrl;
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.roomId,
    this.isOnline = false,
    this.accessOpen = true,
    this.isSleeping = false,
    this.sleepStartedAt,
    this.sleepMusicEnabled = true,
    this.profilePhotoUrl,
    this.createdAt,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isRoomOwner => roomId != null;

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      role: userRoleFromString(map['role'] as String? ?? 'member'),
      roomId: map['roomId'] as String?,
      isOnline: map['isOnline'] as bool? ?? false,
      accessOpen: map['accessOpen'] as bool? ?? true,
      isSleeping: map['isSleeping'] as bool? ?? false,
      sleepStartedAt: (map['sleepStartedAt'] as Timestamp?)?.toDate(),
      sleepMusicEnabled: map['sleepMusicEnabled'] as bool? ?? true,
      profilePhotoUrl: map['profilePhotoUrl'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role.name,
      'roomId': roomId,
      'isOnline': isOnline,
      'accessOpen': accessOpen,
      'isSleeping': isSleeping,
      'sleepStartedAt':
          sleepStartedAt != null ? Timestamp.fromDate(sleepStartedAt!) : null,
      'sleepMusicEnabled': sleepMusicEnabled,
      'profilePhotoUrl': profilePhotoUrl,
      'createdAt':
          createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
