import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) {
    return ChatMessage(
      id: id,
      senderUid: map['senderUid'] as String? ?? '',
      text: map['text'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderUid': senderUid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };
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

  factory ChatSummary.fromMap(String id, Map<String, dynamic> map) {
    final rawLastRead = (map['lastReadAt'] as Map<String, dynamic>?) ?? {};
    return ChatSummary(
      id: id,
      participants: List<String>.from(map['participants'] as List? ?? []),
      participantNames: Map<String, String>.from(
          map['participantNames'] as Map? ?? {}),
      lastMessage: map['lastMessage'] as String? ?? '',
      lastMessageAt: (map['lastMessageAt'] as Timestamp?)?.toDate(),
      lastSenderUid: map['lastSenderUid'] as String?,
      lastReadAt: rawLastRead.map(
          (key, value) => MapEntry(key, (value as Timestamp).toDate())),
    );
  }
}
