class RoomBrief {
  final int id;
  final String name;
  final String accessStatus;
  final bool knockEnabled;

  RoomBrief({
    required this.id,
    required this.name,
    required this.accessStatus,
    required this.knockEnabled,
  });

  factory RoomBrief.fromJson(Map<String, dynamic> json) => RoomBrief(
        id: json['id'] as int,
        name: json['name'] as String,
        accessStatus: json['accessStatus'] as String,
        knockEnabled: json['knockEnabled'] as bool,
      );
}

class StatusEntry {
  final int userId;
  final String displayName;
  final String? profilePhoto;
  final bool online;
  final String sleepStatus;
  final bool isAdmin;
  final RoomBrief? room;
  final List<String> todaySchedules;

  StatusEntry({
    required this.userId,
    required this.displayName,
    required this.profilePhoto,
    required this.online,
    required this.sleepStatus,
    required this.isAdmin,
    required this.room,
    required this.todaySchedules,
  });

  factory StatusEntry.fromJson(Map<String, dynamic> json) => StatusEntry(
        userId: json['userId'] as int,
        displayName: json['displayName'] as String,
        profilePhoto: json['profilePhoto'] as String?,
        online: json['online'] as bool,
        sleepStatus: json['sleepStatus'] as String,
        isAdmin: json['isAdmin'] as bool,
        room: json['room'] != null ? RoomBrief.fromJson(json['room'] as Map<String, dynamic>) : null,
        todaySchedules: (json['todaySchedules'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
      );
}
