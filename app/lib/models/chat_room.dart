class GroupMessage {
  final int id;
  final int roomId;
  final int senderId;
  final String? senderName;
  final String content;
  final String createdAt;

  GroupMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.createdAt,
  });

  factory GroupMessage.fromJson(Map<String, dynamic> json) => GroupMessage(
        id: json['id'] as int,
        roomId: json['roomId'] as int,
        senderId: json['senderId'] as int,
        senderName: json['senderName'] as String?,
        content: json['content'] as String,
        createdAt: json['createdAt'] as String,
      );
}

class ChatRoomMember {
  final int id;
  final String displayName;

  ChatRoomMember({required this.id, required this.displayName});

  factory ChatRoomMember.fromJson(Map<String, dynamic> json) => ChatRoomMember(
        id: json['id'] as int,
        displayName: json['displayName'] as String,
      );
}

class ChatRoom {
  final int id;
  final String name;
  final int createdBy;
  final String createdAt;
  final List<ChatRoomMember> members;
  final GroupMessage? lastMessage;
  final int unreadCount;

  ChatRoom({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    required this.members,
    required this.lastMessage,
    required this.unreadCount,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) => ChatRoom(
        id: json['id'] as int,
        name: json['name'] as String,
        createdBy: json['createdBy'] as int,
        createdAt: json['createdAt'] as String,
        members: (json['members'] as List<dynamic>? ?? [])
            .map((e) => ChatRoomMember.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        lastMessage: json['lastMessage'] != null
            ? GroupMessage.fromJson(Map<String, dynamic>.from(json['lastMessage'] as Map))
            : null,
        unreadCount: json['unreadCount'] as int? ?? 0,
      );
}
