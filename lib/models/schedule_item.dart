import 'package:cloud_firestore/cloud_firestore.dart';

/// 일정: 특정 날(년/월/일)에 해야 할 일을 알려주는 항목.
class ScheduleItem {
  final String id;
  final String uid;
  final String ownerName;

  /// 'yyyy/MM/dd' 형식의 날짜 (한국 표준시 기준).
  final String date;
  final String title;
  final String? memo;
  final DateTime? createdAt;

  const ScheduleItem({
    required this.id,
    required this.uid,
    required this.ownerName,
    required this.date,
    required this.title,
    this.memo,
    this.createdAt,
  });

  factory ScheduleItem.fromMap(String id, Map<String, dynamic> map) {
    return ScheduleItem(
      id: id,
      uid: map['uid'] as String? ?? '',
      ownerName: map['ownerName'] as String? ?? '',
      date: map['date'] as String? ?? '',
      title: map['title'] as String? ?? '',
      memo: map['memo'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'ownerName': ownerName,
      'date': date,
      'title': title,
      'memo': memo,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}
