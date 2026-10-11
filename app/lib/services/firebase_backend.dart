import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import '../models/user.dart';
import 'api_exception.dart';

/// PC(로컬) 서버에 연결할 수 없을 때 로그인/상태창/1:1 매신저를 대신하는
/// Firebase Authentication + Firestore 백엔드. backend/src/utils/firebaseAuthMirror.js가
/// 계정이 바뀔 때마다 Firestore에 반영해 둔 users/{sqlId} 문서, uid_index/{uid}
/// 역매핑을 그대로 읽는다.
///
/// 이 클래스가 만드는 JSON은 Node/Dart 서버의 REST 응답과 같은 모양(필드명)으로
/// 맞춰서, ApiClient가 흉내 낼 때 화면 쪽 모델(AppUser.fromJson 등)을 그대로
/// 재사용할 수 있게 한다.
class FirebaseBackend {
  bool? _available;
  int? _sqlId;
  String? _pendingUsername;

  int? get currentSqlId => _sqlId;

  /// register()로 Firebase 모드에서 막 가입했지만, 아직 PC 서버가 SQLite
  /// 계정으로 동기화해주지 않아서 로그인/제한된 기능만 쓸 수 있는 상태라면
  /// 그 아이디를 돌려준다. 동기화가 끝나면(다른 기기에서 로그인해도) null이 된다.
  String? get pendingUsername => _pendingUsername;

  Future<bool> ensureInitialized() async {
    if (_available != null) return _available!;
    try {
      if (Firebase.apps.isEmpty) {
        final options = DefaultFirebaseOptions.currentPlatform;
        if (options != null) {
          await Firebase.initializeApp(options: options);
        } else {
          await Firebase.initializeApp();
        }
      }
      _available = true;
    } catch (_) {
      _available = false;
    }
    return _available!;
  }

  String _syntheticEmail(String username) => '$username@famil-app.local';

  Future<AppUser> login(String username, String password) async {
    if (!await ensureInitialized()) {
      throw ApiException('이 플랫폼에는 Firebase가 설정되어 있지 않습니다.');
    }
    UserCredential cred;
    try {
      cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _syntheticEmail(username),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw ApiException(_mapAuthError(e));
    }
    final user = await _resolveProfile(cred.user!.uid);
    if (user == null) {
      await FirebaseAuth.instance.signOut();
      throw ApiException('Firebase에 동기화된 계정 정보를 찾을 수 없습니다. PC 서버가 켜져 있을 때 한 번 더 로그인해주세요.');
    }
    return user;
  }

  /// 앱 재시작 시 Firebase Auth에 남아있는 로그인 상태를 복원한다.
  Future<AppUser?> restoreSession() async {
    if (!await ensureInitialized()) return null;
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return null;
    return _resolveProfile(current.uid);
  }

  Future<void> logout() async {
    _sqlId = null;
    _pendingUsername = null;
    if (_available == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  Future<AppUser?> _resolveProfile(String uid) async {
    final indexDoc = await FirebaseFirestore.instance.collection('uid_index').doc(uid).get();
    final sqlId = (indexDoc.data()?['sqlId'] as num?)?.toInt();
    if (sqlId == null) return null;
    final profileDoc = await FirebaseFirestore.instance.collection('users').doc(sqlId.toString()).get();
    if (!profileDoc.exists) return null;
    _sqlId = sqlId;
    _pendingUsername = null;
    return AppUser.fromJson(_profileJson(sqlId, profileDoc.data()!));
  }

  /// PC가 꺼져 있을 때 Firebase 모드로 회원가입한다. 아직 SQLite 쪽에는
  /// 계정이 없어서(그래서 id가 없다 - 음수 -1을 "동기화 전" 표시로 쓴다),
  /// PC가 켜지고 처음 로그인할 때 자동으로 완전히 연동된다. 그 전까지는
  /// 로그인은 되지만 가족 목록에 보이거나 메신저를 쓸 수는 없다.
  Future<AppUser> register(String username, String password, String displayName) async {
    if (!await ensureInitialized()) {
      throw ApiException('이 플랫폼에는 Firebase가 설정되어 있지 않습니다.');
    }
    final trimmed = username.trim();
    if (await _usernameTaken(trimmed)) {
      throw ApiException('이미 사용 중인 아이디입니다.');
    }

    UserCredential cred;
    try {
      cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _syntheticEmail(trimmed),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw ApiException(_mapAuthError(e));
    }

    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await FirebaseFirestore.instance.collection('pending_registrations').doc(cred.user!.uid).set({
        'username': trimmed,
        'displayName': displayName,
        'createdAt': now,
      });
    } catch (_) {
      throw ApiException('가입 정보를 저장하지 못했습니다. 인터넷 연결을 확인해주세요.');
    }

    _pendingUsername = trimmed;
    return AppUser(
      id: -1,
      username: trimmed,
      displayName: displayName,
      isAdmin: false,
      profilePhoto: null,
      sleepStatus: 'awake',
      sleepSoundEnabled: true,
      sleepSoundId: 'lullaby1',
      online: false,
      roomId: null,
      createdAt: now,
    );
  }

  Future<bool> _usernameTaken(String username) async {
    final usersSnap =
        await FirebaseFirestore.instance.collection('users').where('username', isEqualTo: username).limit(1).get();
    if (usersSnap.docs.isNotEmpty) return true;
    final pendingSnap = await FirebaseFirestore.instance
        .collection('pending_registrations')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return pendingSnap.docs.isNotEmpty;
  }

  /// 로컬(PC) 서버가 다시 켜졌을 때, Firebase에만 있던 계정을 그 서버로
  /// 옮기기 위해 쓰는 신원 증명서(idToken)를 받아온다. 비밀번호가 맞아야만
  /// Firebase가 토큰을 내준다. AuthProvider가 이걸 `/auth/sync-firebase-account`로
  /// 보내서 로컬 계정을 만든다 - 성공/실패와 무관하게 이 메서드 자체는 로그인
  /// 상태(_sqlId)를 바꾸지 않는다.
  Future<String?> signInAndGetIdToken(String username, String password) async {
    if (!await ensureInitialized()) return null;
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _syntheticEmail(username),
        password: password,
      );
      return await cred.user!.getIdToken();
    } catch (_) {
      return null;
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-email':
        return '아이디 또는 비밀번호가 올바르지 않습니다.';
      case 'user-disabled':
        return '사용이 제한된 계정입니다.';
      case 'too-many-requests':
        return '너무 많이 시도했습니다. 잠시 후 다시 시도해주세요.';
      case 'network-request-failed':
        return 'Firebase 서버에 연결할 수 없습니다.';
      default:
        return e.message ?? 'Firebase 로그인에 실패했습니다.';
    }
  }

  Map<String, dynamic> _profileJson(int sqlId, Map<String, dynamic> data) => {
        'id': sqlId,
        'username': data['username'] ?? '',
        'displayName': data['displayName'] ?? '(알 수 없음)',
        'isAdmin': data['isAdmin'] ?? false,
        'profilePhoto': data['profilePhoto'],
        'sleepStatus': 'awake',
        'online': false,
      };

  /// GET /users 흉내: 가족 전체 목록(상태창 데이터는 없는 기본 프로필만).
  Future<Map<String, dynamic>> fetchUsersJson() async {
    final snap = await FirebaseFirestore.instance.collection('users').get();
    final users = snap.docs
        .map((doc) => _profileJson(int.tryParse(doc.id) ?? 0, doc.data()))
        .toList()
      ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    return {'users': users};
  }

  /// GET /status 흉내: 방/노크/일정 정보는 미러링하지 않으므로 빈 값으로 채운다.
  /// StatusBoardScreen은 room이 null이면 "배정된 방 없음"으로 표시하도록
  /// 이미 만들어져 있어서, 화면 코드를 손대지 않아도 그대로 동작한다.
  Future<Map<String, dynamic>> fetchStatusBoardJson() async {
    final usersRes = await fetchUsersJson();
    final board = (usersRes['users'] as List<dynamic>).map((u) {
      final user = u as Map<String, dynamic>;
      return {
        'userId': user['id'],
        'displayName': user['displayName'],
        'profilePhoto': user['profilePhoto'],
        'online': false,
        'sleepStatus': 'awake',
        'isAdmin': user['isAdmin'],
        'room': null,
        'todaySchedules': <String>[],
      };
    }).toList();
    return {'board': board};
  }

  String _pairKey(int a, int b) {
    final ids = [a, b]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// GET /messages/conversations 흉내: 내가 참여한 1:1 대화방 목록.
  Future<Map<String, dynamic>> fetchConversationsJson() async {
    final myId = _sqlId;
    if (myId == null) return {'conversations': []};

    final snap = await FirebaseFirestore.instance
        .collection('direct_messages')
        .where('participantIds', arrayContains: myId)
        .get();
    final usersRes = await fetchUsersJson();
    final usersById = <int, Map<String, dynamic>>{
      for (final u in (usersRes['users'] as List<dynamic>)) (u as Map<String, dynamic>)['id'] as int: u,
    };

    final conversations = snap.docs.map((doc) {
      final data = doc.data();
      final ids = (data['participantIds'] as List<dynamic>).map((e) => (e as num).toInt()).toList();
      final partnerId = ids.firstWhere((id) => id != myId, orElse: () => myId);
      return {
        'partner': usersById[partnerId],
        'lastMessage': data['lastMessage'],
        'unreadCount': 0,
      };
    }).toList();

    conversations.sort((a, b) {
      final am = a['lastMessage'] as Map<String, dynamic>?;
      final bm = b['lastMessage'] as Map<String, dynamic>?;
      return (bm?['createdAt'] as String? ?? '').compareTo(am?['createdAt'] as String? ?? '');
    });
    return {'conversations': conversations};
  }

  /// GET /messages/:partnerId 흉내: 실시간 구독 없이, 화면이 새로고침할 때마다
  /// (풀 리프레시, 앱 재진입, 전송 직후) 다시 불러오는 방식으로 동작한다.
  Future<Map<String, dynamic>> fetchDirectMessagesJson(int partnerId) async {
    final myId = _sqlId;
    if (myId == null) return {'messages': []};
    final key = _pairKey(myId, partnerId);
    final snap = await FirebaseFirestore.instance
        .collection('direct_messages')
        .doc(key)
        .collection('items')
        .orderBy('createdAt')
        .get();
    return {'messages': snap.docs.map((d) => d.data()).toList()};
  }

  Future<void> sendDirectMessage(int partnerId, String content) async {
    final myId = _sqlId;
    if (myId == null) throw ApiException('로그인이 필요합니다.');
    final key = _pairKey(myId, partnerId);
    final now = DateTime.now().toUtc();
    final message = {
      'id': now.millisecondsSinceEpoch,
      'senderId': myId,
      'receiverId': partnerId,
      'content': content,
      'createdAt': now.toIso8601String(),
      'readAt': null,
    };
    final ref = FirebaseFirestore.instance.collection('direct_messages').doc(key);
    try {
      await ref.set({
        'participantIds': [myId, partnerId],
        'lastMessage': message,
      }, SetOptions(merge: true));
      await ref.collection('items').add(message);
    } catch (_) {
      throw ApiException('메시지를 보내지 못했습니다. 인터넷 연결을 확인해주세요.');
    }
  }
}
