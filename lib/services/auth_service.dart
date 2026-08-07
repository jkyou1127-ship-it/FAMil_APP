import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

/// 로그인/회원가입 및 "첫 계정 = 관리자" 규칙을 담당한다.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  static const _adminFlagDocPath = 'meta/adminAssigned';

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  Future<AppUser?> loadAppUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(uid, doc.data()!);
  }

  Stream<AppUser?> watchAppUser(String uid) {
    return _users.doc(uid).snapshots().map(
        (doc) => doc.exists ? AppUser.fromMap(uid, doc.data()!) : null);
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user!.uid;
    await _users.doc(uid).update({'isOnline': true});
    final appUser = await loadAppUser(uid);
    if (appUser == null) {
      throw StateError('사용자 정보를 찾을 수 없습니다.');
    }
    return appUser;
  }

  /// 회원가입. 시스템에 관리자 계정이 아직 없다면("첫" 계정) 이 계정이
  /// 자동으로 관리자가 된다. Firestore 트랜잭션으로 관리자 중복 배정을 막는다.
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user!.uid;

    final role = await _db.runTransaction<UserRole>((transaction) async {
      final adminFlagRef = _db.doc(_adminFlagDocPath);
      final adminFlagSnap = await transaction.get(adminFlagRef);
      if (adminFlagSnap.exists) {
        return UserRole.member;
      }
      transaction.set(adminFlagRef, {
        'uid': uid,
        'assignedAt': FieldValue.serverTimestamp(),
      });
      return UserRole.admin;
    });

    final appUser = AppUser(
      uid: uid,
      email: email.trim(),
      displayName: displayName.trim(),
      role: role,
      isOnline: true,
      createdAt: DateTime.now(),
    );
    await _users.doc(uid).set(appUser.toMap());
    return appUser;
  }

  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _users.doc(uid).update({'isOnline': false}).catchError((_) {});
    }
    await _auth.signOut();
  }
}
