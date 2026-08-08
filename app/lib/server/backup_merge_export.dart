import 'package:sqlite3/sqlite3.dart';

import '../models/backup_snapshot.dart';

/// 백업 서버(폰)로 동작하는 동안 새로 생긴 데이터 중, 출입 전부터 있던 사용자/
/// 방/단톡방을 참조하는 것만 골라 주 서버로 병합 전송할 형태로 내보낸다.
/// 백업 중 새로 생긴 사용자/방/단톡방을 참조하는 데이터는 주 서버에 대응하는
/// 대상이 없을 수 있어 제외한다 — backend/src/routes/backup.js의
/// POST /backup/merge-import가 기대하는 형식과 맞춰야 한다.
Map<String, dynamic> exportNewRowsForMerge(Database db, SnapshotMeta meta) {
  final cutoff = meta.takenAt.toIso8601String();

  final messages = db.select(
    'SELECT sender_id, receiver_id, content, created_at FROM messages '
    'WHERE created_at > ? AND sender_id <= ? AND receiver_id <= ?',
    [cutoff, meta.maxUserId, meta.maxUserId],
  );
  final chatRoomMessages = db.select(
    'SELECT room_id, sender_id, content, created_at FROM chat_room_messages '
    'WHERE created_at > ? AND room_id <= ? AND sender_id <= ?',
    [cutoff, meta.maxChatRoomId, meta.maxUserId],
  );
  final todos = db.select(
    'SELECT user_id, content, completed, completed_date, created_at FROM todos '
    'WHERE created_at > ? AND user_id <= ?',
    [cutoff, meta.maxUserId],
  );
  final schedules = db.select(
    'SELECT user_id, date, content, created_at FROM schedules '
    'WHERE created_at > ? AND user_id <= ?',
    [cutoff, meta.maxUserId],
  );
  final suggestions = db.select('SELECT content, created_at FROM suggestions WHERE created_at > ?', [cutoff]);
  final shoppingItems = db.select(
    'SELECT content, added_by, bought, bought_by, created_at, bought_at FROM shopping_items '
    'WHERE created_at > ? AND added_by <= ? AND (bought_by IS NULL OR bought_by <= ?)',
    [cutoff, meta.maxUserId, meta.maxUserId],
  );

  return {
    'messages': messages
        .map((r) => {
              'senderId': r['sender_id'],
              'receiverId': r['receiver_id'],
              'content': r['content'],
              'createdAt': r['created_at'],
            })
        .toList(),
    'chatRoomMessages': chatRoomMessages
        .map((r) => {
              'roomId': r['room_id'],
              'senderId': r['sender_id'],
              'content': r['content'],
              'createdAt': r['created_at'],
            })
        .toList(),
    'todos': todos
        .map((r) => {
              'userId': r['user_id'],
              'content': r['content'],
              'completed': (r['completed'] as int) != 0,
              'completedDate': r['completed_date'],
              'createdAt': r['created_at'],
            })
        .toList(),
    'schedules': schedules
        .map((r) => {
              'userId': r['user_id'],
              'date': r['date'],
              'content': r['content'],
              'createdAt': r['created_at'],
            })
        .toList(),
    'suggestions': suggestions.map((r) => {'content': r['content'], 'createdAt': r['created_at']}).toList(),
    'shoppingItems': shoppingItems
        .map((r) => {
              'content': r['content'],
              'addedBy': r['added_by'],
              'bought': (r['bought'] as int) != 0,
              'boughtBy': r['bought_by'],
              'createdAt': r['created_at'],
              'boughtAt': r['bought_at'],
            })
        .toList(),
  };
}
