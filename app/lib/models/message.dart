class ChatMessage {
  final int id;
  final int senderId;
  final int receiverId;
  final String content;
  final String createdAt;
  final String? readAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.createdAt,
    required this.readAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as int,
        senderId: json['senderId'] as int,
        receiverId: json['receiverId'] as int,
        content: json['content'] as String,
        createdAt: json['createdAt'] as String,
        readAt: json['readAt'] as String?,
      );
}

class Conversation {
  final int? partnerId;
  final String partnerName;
  final String? partnerPhoto;
  final bool partnerOnline;
  final ChatMessage? lastMessage;
  final int unreadCount;

  Conversation({
    required this.partnerId,
    required this.partnerName,
    required this.partnerPhoto,
    required this.partnerOnline,
    required this.lastMessage,
    required this.unreadCount,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final partner = json['partner'] as Map<String, dynamic>?;
    return Conversation(
      partnerId: partner?['id'] as int?,
      partnerName: partner?['displayName'] as String? ?? '(알 수 없음)',
      partnerPhoto: partner?['profilePhoto'] as String?,
      partnerOnline: partner?['online'] as bool? ?? false,
      lastMessage: json['lastMessage'] != null
          ? ChatMessage.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }
}
