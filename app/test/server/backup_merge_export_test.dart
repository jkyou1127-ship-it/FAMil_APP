import 'dart:io';

import 'package:famil_app/models/backup_snapshot.dart';
import 'package:famil_app/server/backup_merge_export.dart';
import 'package:famil_app/server/db/schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('스냅샷 이후 새 데이터 중 기존 사용자/방/단톡방을 참조하는 것만 내보낸다', () {
    final tempDir = Directory.systemTemp.createTempSync('famil_merge_export_test_');
    final db = openFamilDatabase('${tempDir.path}/test.db');

    void insertUser(String username) {
      db.execute(
        "INSERT INTO users (username, password_hash, display_name, created_at) VALUES (?, 'hash', ?, datetime('now'))",
        [username, username],
      );
    }

    insertUser('alice');
    insertUser('bob');
    final aliceId = db.select('SELECT id FROM users WHERE username = ?', ['alice']).first['id'] as int;
    final bobId = db.select('SELECT id FROM users WHERE username = ?', ['bob']).first['id'] as int;

    db.execute(
      "INSERT INTO chat_rooms (name, created_by, created_at) VALUES ('가족방', ?, datetime('now'))",
      [aliceId],
    );
    final chatRoomId = db.select('SELECT id FROM chat_rooms').first['id'] as int;

    // 스냅샷 기준점: 지금까지의 사용자/방/단톡방 최대 id, 그리고 "지금"보다 뒤의 데이터만 새 데이터로 취급.
    final meta = SnapshotMeta(
      takenAt: DateTime.now().toUtc(),
      maxUserId: bobId,
      maxRoomId: 0,
      maxChatRoomId: chatRoomId,
    );

    // 스냅샷 이후, 기존 대상(사용자/단톡방)을 참조하는 새 데이터.
    final after = DateTime.now().toUtc().add(const Duration(seconds: 1)).toIso8601String();
    db.execute(
      'INSERT INTO messages (sender_id, receiver_id, content, created_at) VALUES (?, ?, ?, ?)',
      [aliceId, bobId, '안녕', after],
    );
    db.execute(
      'INSERT INTO chat_room_messages (room_id, sender_id, content, created_at) VALUES (?, ?, ?, ?)',
      [chatRoomId, bobId, '단톡방 메시지', after],
    );
    db.execute(
      'INSERT INTO todos (user_id, content, completed, created_at) VALUES (?, ?, 0, ?)',
      [aliceId, '병합될 할일', after],
    );
    db.execute(
      'INSERT INTO suggestions (content, created_at) VALUES (?, ?)',
      ['병합될 건의사항', after],
    );

    // 스냅샷 이후 새로 생긴 사용자/단톡방을 참조하는 데이터는 제외되어야 한다.
    insertUser('charlie');
    final charlieId = db.select('SELECT id FROM users WHERE username = ?', ['charlie']).first['id'] as int;
    db.execute(
      'INSERT INTO messages (sender_id, receiver_id, content, created_at) VALUES (?, ?, ?, ?)',
      [aliceId, charlieId, '새 사용자에게 보낸 메시지 - 제외되어야 함', after],
    );

    // 스냅샷 이전 데이터(취침 전 이미 있던 메시지)도 제외되어야 한다.
    final before = meta.takenAt.subtract(const Duration(days: 1)).toIso8601String();
    db.execute(
      'INSERT INTO messages (sender_id, receiver_id, content, created_at) VALUES (?, ?, ?, ?)',
      [aliceId, bobId, '스냅샷 이전 메시지 - 제외되어야 함', before],
    );

    final result = exportNewRowsForMerge(db, meta);

    final messages = result['messages'] as List;
    expect(messages.length, 1);
    expect(messages.first['content'], '안녕');

    final chatRoomMessages = result['chatRoomMessages'] as List;
    expect(chatRoomMessages.length, 1);
    expect(chatRoomMessages.first['content'], '단톡방 메시지');

    final todos = result['todos'] as List;
    expect(todos.length, 1);
    expect(todos.first['content'], '병합될 할일');

    final suggestions = result['suggestions'] as List;
    expect(suggestions.length, 1);
    expect(suggestions.first['content'], '병합될 건의사항');

    db.close();
    tempDir.deleteSync(recursive: true);
  });
}
