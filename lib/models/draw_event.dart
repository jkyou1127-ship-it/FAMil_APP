import 'package:cloud_firestore/cloud_firestore.dart';

/// 추첨 시스템: 현재 인원 중 무작위로 한 명을 뽑은 기록.
class DrawEvent {
  final String id;
  final String? title;
  final List<String> participantUids;
  final List<String> participantNames;
  final String winnerUid;
  final String winnerName;
  final String createdByUid;
  final DateTime? createdAt;

  const DrawEvent({
    required this.id,
    this.title,
    required this.participantUids,
    required this.participantNames,
    required this.winnerUid,
    required this.winnerName,
    required this.createdByUid,
    this.createdAt,
  });

  factory DrawEvent.fromMap(String id, Map<String, dynamic> map) {
    return DrawEvent(
      id: id,
      title: map['title'] as String?,
      participantUids: List<String>.from(map['participantUids'] as List? ?? []),
      participantNames:
          List<String>.from(map['participantNames'] as List? ?? []),
      winnerUid: map['winnerUid'] as String? ?? '',
      winnerName: map['winnerName'] as String? ?? '',
      createdByUid: map['createdByUid'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'participantUids': participantUids,
      'participantNames': participantNames,
      'winnerUid': winnerUid,
      'winnerName': winnerName,
      'createdByUid': createdByUid,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
