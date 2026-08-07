import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/suggestion.dart';

class SuggestionRepository {
  SuggestionRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _suggestions =>
      _db.collection('suggestions');

  /// 모두가 볼 수 있는 익명 건의사항 목록(실시간).
  Stream<List<Suggestion>> watchAll() {
    return _suggestions
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Suggestion.fromMap(d.id, d.data())).toList());
  }

  Future<void> submit(String text) {
    return _suggestions.add(Suggestion(id: '', text: text).toMap());
  }
}
