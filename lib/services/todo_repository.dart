import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/todo_item.dart';
import 'kst_time.dart';

class TodoRepository {
  TodoRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _todos =>
      _db.collection('todos');

  Stream<List<TodoItem>> watchMyTodos(String uid) {
    return _todos
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => TodoItem.fromMap(d.id, d.data())).toList());
  }

  Future<void> addTodo(String uid, String text) {
    return _todos.add(TodoItem(id: '', uid: uid, text: text).toMap());
  }

  Future<void> setDone(String todoId, bool done) {
    return _todos.doc(todoId).update({
      'done': done,
      'doneAt': done ? Timestamp.fromDate(DateTime.now()) : null,
    });
  }

  Future<void> deleteTodo(String todoId) {
    return _todos.doc(todoId).delete();
  }

  /// 완료(취소선) 처리된 지 하루(한국 표준시 기준 날짜가 바뀜)가 지난
  /// 할 일을 삭제한다. 할일 목록 화면 진입 시 호출한다.
  Future<void> cleanupStaleDoneTodos(String uid) async {
    final now = KstTime.now();
    final snap = await _todos
        .where('uid', isEqualTo: uid)
        .where('done', isEqualTo: true)
        .get();
    final batch = _db.batch();
    var hasDeletes = false;
    for (final doc in snap.docs) {
      final item = TodoItem.fromMap(doc.id, doc.data());
      if (item.doneAt == null) continue;
      if (!KstTime.isSameKstDay(item.doneAt!, now)) {
        batch.delete(doc.reference);
        hasDeletes = true;
      }
    }
    if (hasDeletes) {
      await batch.commit();
    }
  }
}
