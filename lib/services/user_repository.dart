import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// 상태창에 표시할 전체 사용자 목록(실시간).
  Stream<List<AppUser>> watchAllUsers() {
    return _users.orderBy('displayName').snapshots().map((snap) =>
        snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList());
  }

  Future<List<AppUser>> fetchAllUsersOnce() async {
    final snap = await _users.get();
    return snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList();
  }

  /// 출입 가능/불가능 상태 변경. 불가능으로 바꾸면 온라인 노크가 비활성화된다.
  Future<void> setAccessOpen(String uid, bool open) {
    return _users.doc(uid).update({'accessOpen': open});
  }

  Future<void> setSleeping(
    String uid, {
    required bool sleeping,
    DateTime? sleepStartedAt,
  }) {
    return _users.doc(uid).update({
      'isSleeping': sleeping,
      'sleepStartedAt':
          sleepStartedAt != null ? Timestamp.fromDate(sleepStartedAt) : null,
    });
  }

  Future<void> setOnline(String uid, bool online) {
    return _users.doc(uid).update({'isOnline': online});
  }

  Future<void> setDisplayName(String uid, String name) {
    return _users.doc(uid).update({'displayName': name});
  }

  Future<void> setProfilePhotoUrl(String uid, String? url) {
    return _users.doc(uid).update({'profilePhotoUrl': url});
  }
}
