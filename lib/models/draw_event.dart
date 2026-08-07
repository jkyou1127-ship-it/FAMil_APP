import '../services/json_time.dart';

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

  factory DrawEvent.fromJson(Map<String, dynamic> json) {
    return DrawEvent(
      id: json['id'] as String,
      title: json['title'] as String?,
      participantUids: List<String>.from(json['participantUids'] as List? ?? []),
      participantNames: List<String>.from(json['participantNames'] as List? ?? []),
      winnerUid: json['winnerUid'] as String? ?? '',
      winnerName: json['winnerName'] as String? ?? '',
      createdByUid: json['createdByUid'] as String? ?? '',
      createdAt: parseTime(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'participantUids': participantUids,
      'participantNames': participantNames,
      'winnerUid': winnerUid,
      'winnerName': winnerName,
    };
  }
}
