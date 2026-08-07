import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/draw_event.dart';

class DrawRepository {
  DrawRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _draws =>
      _db.collection('draws');

  Stream<List<DrawEvent>> watchHistory() {
    return _draws
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => DrawEvent.fromMap(d.id, d.data())).toList());
  }

  Future<void> saveDraw(DrawEvent event) {
    return _draws.add(event.toMap());
  }
}
