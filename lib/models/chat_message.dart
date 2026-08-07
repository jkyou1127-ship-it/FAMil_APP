import '../services/json_time.dart';

class ChatMessage {
  final String id;
  final String senderUid;
  final String text;
  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.text,
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      senderUid: json['senderUid'] as String? ?? '',
      text: json['text'] as String? ?? '',
      createdAt: parseTime(json['createdAt']),
    );
  }
}

/// 1:1 대화방 요약 정보 (대화목록 화면용).
class ChatSummary {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSenderUid;
  final Map<String, DateTime> lastReadAt;

  const ChatSummary({
    required this.id,
    required this.participants,
    required this.participantNames,
    this.lastMessage = '',
    this.lastMessageAt,
    this.lastSenderUid,
    this.lastReadAt = const {},
  });

  String otherUid(String myUid) =>
      participants.firstWhere((u) => u != myUid, orElse: () => '');

  String otherName(String myUid) =>
      participantNames[otherUid(myUid)] ?? '알 수 없음';

  bool hasUnread(String myUid) {
    if (lastMessageAt == null) return false;
    if (lastSenderUid == myUid) return false;
    final read = lastReadAt[myUid];
    if (read == null) return true;
    return lastMessageAt!.isAfter(read);
  }

  factory ChatSummary.fromJson(Map<String, dynamic> json) {
    final rawLastRead = (json['lastReadAt'] as Map?) ?? {};
    return ChatSummary(
      id: json['id'] as String,
      participants: List<String>.from(json['participants'] as List? ?? []),
      participantNames:
          Map<String, String>.from(json['participantNames'] as Map? ?? {}),
      lastMessage: json['lastMessage'] as String? ?? '',
      lastMessageAt: parseTime(json['lastMessageAt']),
      lastSenderUid: json['lastSenderUid'] as String?,
      lastReadAt: rawLastRead.map(
          (key, value) => MapEntry(key as String, parseTime(value)!)),
    );
  }
}
