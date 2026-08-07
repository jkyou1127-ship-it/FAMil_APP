class AppUser {
  final int id;
  final String username;
  final String displayName;
  final bool isAdmin;
  final String? profilePhoto;
  final String sleepStatus; // 'awake' | 'sleeping'
  final bool sleepSoundEnabled;
  final bool online;
  final int? roomId;
  final String createdAt;

  AppUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.isAdmin,
    required this.profilePhoto,
    required this.sleepStatus,
    required this.sleepSoundEnabled,
    required this.online,
    required this.roomId,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        username: json['username'] as String,
        displayName: json['displayName'] as String,
        isAdmin: json['isAdmin'] as bool? ?? false,
        profilePhoto: json['profilePhoto'] as String?,
        sleepStatus: json['sleepStatus'] as String? ?? 'awake',
        sleepSoundEnabled: json['sleepSoundEnabled'] as bool? ?? true,
        online: json['online'] as bool? ?? false,
        roomId: json['roomId'] as int?,
        createdAt: json['createdAt'] as String? ?? '',
      );
}
