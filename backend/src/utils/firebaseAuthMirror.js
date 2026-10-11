const fs = require('fs');
const path = require('path');

// PC 백엔드가 꺼져 있을 때도 Firebase 모드로 똑같은 아이디/비밀번호로 로그인하고
// 가족 목록을 볼 수 있도록, 계정이 생성/변경/삭제될 때마다 Firebase
// Authentication(로그인)과 Firestore(users/{id} 프로필 문서)에도 반영해둔다.
// push.js의 FCM 초기화와 동일한 서비스 계정 파일을 쓰고, 같은 방식으로
// "설정 안 돼 있으면 조용히 비활성화"한다 — PC 모드 자체에는 영향이 없다
// (Firebase 모드만 그동안 최신 상태가 아니게 된다).
//
// 주의: sleepStatus/online처럼 실시간으로 바뀌는 값은 미러링하지 않는다 —
// 그러려면 ws_hub.js의 모든 상태 변경 지점을 함께 손봐야 해서 범위가 너무
// 커진다. Firebase 모드의 상태창은 마지막으로 동기화된 프로필 기준으로만
// 보여준다 (이름/사진/관리자 여부).
let authAdmin = null;
let firestoreAdmin = null;

function serviceAccountPath() {
  return process.env.FIREBASE_SERVICE_ACCOUNT_PATH
    ? path.resolve(process.env.FIREBASE_SERVICE_ACCOUNT_PATH)
    : path.join(__dirname, '..', '..', 'firebase-service-account.json');
}

function firebaseApp() {
  const keyPath = serviceAccountPath();
  if (!fs.existsSync(keyPath)) return null;
  const { initializeApp, cert, getApps } = require('firebase-admin/app');
  const serviceAccount = JSON.parse(fs.readFileSync(keyPath, 'utf8'));
  return getApps().length ? getApps()[0] : initializeApp({ credential: cert(serviceAccount) });
}

function initFirebaseAuth() {
  if (authAdmin !== null) return authAdmin;
  try {
    const app = firebaseApp();
    if (!app) {
      authAdmin = false;
      return authAdmin;
    }
    const { getAuth } = require('firebase-admin/auth');
    authAdmin = getAuth(app);
  } catch (err) {
    console.error('Firebase Auth 초기화 실패, 계정 미러링이 비활성화됩니다:', err.message);
    authAdmin = false;
  }
  return authAdmin;
}

function initFirestore() {
  if (firestoreAdmin !== null) return firestoreAdmin;
  try {
    const app = firebaseApp();
    if (!app) {
      firestoreAdmin = false;
      return firestoreAdmin;
    }
    const { getFirestore } = require('firebase-admin/firestore');
    firestoreAdmin = getFirestore(app);
  } catch (err) {
    console.error('Firestore 초기화 실패, 프로필 미러링이 비활성화됩니다:', err.message);
    firestoreAdmin = false;
  }
  return firestoreAdmin;
}

// Firebase Authentication은 이메일 형식의 아이디를 요구하므로, 로그인용
// username을 고정 도메인의 이메일로 바꿔서 쓴다 (실제 메일함은 아니다).
function syntheticEmail(username) {
  return `${username}@famil-app.local`;
}

async function writeProfile(sqlId, fields) {
  const firestore = initFirestore();
  if (!firestore) return;
  try {
    await firestore.collection('users').doc(String(sqlId)).set(fields, { merge: true });
  } catch (err) {
    console.error('Firestore 프로필 동기화 실패:', err.message);
  }
}

// Flutter 클라이언트가 Firebase Auth 로그인 직후 "내 SQLite id가 몇 번이지?"를
// 쿼리 없이 바로 알 수 있도록, uid -> sqlId 역매핑도 함께 보관한다. 이게 있으면
// Firestore 보안 규칙도 users 컬렉션을 스캔하지 않고 간단한 문서 조회로 "이
// 요청자가 본인 데이터에 접근하는지"를 검증할 수 있다.
async function writeUidIndex(uid, sqlId) {
  if (!uid) return;
  const firestore = initFirestore();
  if (!firestore) return;
  try {
    await firestore.collection('uid_index').doc(uid).set({ sqlId });
  } catch (err) {
    console.error('Firestore uid_index 동기화 실패:', err.message);
  }
}

async function deleteUidIndex(uid) {
  if (!uid) return;
  const firestore = initFirestore();
  if (!firestore) return;
  try {
    await firestore.collection('uid_index').doc(uid).delete();
  } catch (err) {
    console.error('Firestore uid_index 삭제 실패:', err.message);
  }
}

async function lookupSqlIdByUid(uid) {
  if (!uid) return null;
  const firestore = initFirestore();
  if (!firestore) return null;
  try {
    const doc = await firestore.collection('uid_index').doc(uid).get();
    return doc.exists ? doc.data().sqlId : null;
  } catch (err) {
    console.error('Firestore uid_index 조회 실패:', err.message);
    return null;
  }
}

// PC가 꺼져 있는 동안 Firebase 모드로 회원가입하면, 아직 SQLite 정수 id가
// 없으므로 uid를 문서 id로 하는 이 컬렉션에 임시로 보관해둔다. PC가 다시
// 켜지고 그 계정으로 처음 로그인을 시도하면(auth.js의 /sync-firebase-account)
// 그때 실제 SQLite 계정을 만들고 이 문서는 지운다.
async function readPendingRegistration(uid) {
  const firestore = initFirestore();
  if (!firestore) return null;
  try {
    const doc = await firestore.collection('pending_registrations').doc(uid).get();
    return doc.exists ? doc.data() : null;
  } catch (err) {
    console.error('Firestore pending_registrations 조회 실패:', err.message);
    return null;
  }
}

async function deletePendingRegistration(uid) {
  const firestore = initFirestore();
  if (!firestore) return;
  try {
    await firestore.collection('pending_registrations').doc(uid).delete();
  } catch (err) {
    console.error('Firestore pending_registrations 삭제 실패:', err.message);
  }
}

/** idToken이 유효하면 그 토큰의 Firebase uid를, 아니면 null을 돌려준다. */
async function verifyIdToken(idToken) {
  const auth = initFirebaseAuth();
  if (!auth || !idToken) return null;
  try {
    const decoded = await auth.verifyIdToken(idToken);
    return decoded.uid;
  } catch (err) {
    console.error('Firebase idToken 검증 실패:', err.message);
    return null;
  }
}

/** 새 계정을 Firebase Authentication + Firestore 프로필에도 만든다. 실패해도 조용히 무시한다. */
async function mirrorCreate(sqlId, username, password, displayName, isAdmin) {
  const auth = initFirebaseAuth();
  let uid = null;
  if (auth) {
    try {
      const record = await auth.createUser({ email: syntheticEmail(username), password, displayName });
      uid = record.uid;
    } catch (err) {
      console.error('Firebase Auth 계정 생성 미러링 실패:', err.message);
    }
  }
  await writeProfile(sqlId, {
    id: sqlId,
    username,
    displayName,
    isAdmin: !!isAdmin,
    profilePhoto: null,
    firebaseUid: uid,
  });
  await writeUidIndex(uid, sqlId);
  return uid;
}

async function mirrorPasswordChange(firebaseUid, newPassword) {
  const auth = initFirebaseAuth();
  if (!auth || !firebaseUid) return;
  try {
    await auth.updateUser(firebaseUid, { password: newPassword });
  } catch (err) {
    console.error('Firebase Auth 비밀번호 변경 미러링 실패:', err.message);
  }
}

async function mirrorUsernameChange(sqlId, firebaseUid, newUsername) {
  const auth = initFirebaseAuth();
  if (auth && firebaseUid) {
    try {
      await auth.updateUser(firebaseUid, { email: syntheticEmail(newUsername) });
    } catch (err) {
      console.error('Firebase Auth 아이디 변경 미러링 실패:', err.message);
    }
  }
  await writeProfile(sqlId, { username: newUsername });
}

/** displayName/profilePhoto처럼 정적인 프로필 필드가 바뀔 때 Firestore만 갱신한다. */
async function mirrorProfileUpdate(sqlId, fields) {
  await writeProfile(sqlId, fields);
}

// mirrorCreate와 달리 Firebase Auth 계정은 이미 존재한다(Firebase 모드에서
// 가입할 때 클라이언트가 직접 만들었다) - 여기서는 그 uid를 새로 만든 SQLite
// 계정에 연결하는 Firestore 쪽 작업만 한다.
async function mirrorLinkExisting(sqlId, uid, fields) {
  await writeProfile(sqlId, { ...fields, firebaseUid: uid });
  await writeUidIndex(uid, sqlId);
}

async function mirrorDelete(sqlId, firebaseUid) {
  const auth = initFirebaseAuth();
  if (auth && firebaseUid) {
    try {
      await auth.deleteUser(firebaseUid);
    } catch (err) {
      console.error('Firebase Auth 계정 삭제 미러링 실패:', err.message);
    }
  }
  const firestore = initFirestore();
  if (firestore) {
    try {
      await firestore.collection('users').doc(String(sqlId)).delete();
    } catch (err) {
      console.error('Firestore 프로필 삭제 미러링 실패:', err.message);
    }
  }
  await deleteUidIndex(firebaseUid);
}

module.exports = {
  mirrorCreate,
  mirrorPasswordChange,
  mirrorUsernameChange,
  mirrorProfileUpdate,
  mirrorLinkExisting,
  mirrorDelete,
  syntheticEmail,
  verifyIdToken,
  lookupSqlIdByUid,
  readPendingRegistration,
  deletePendingRegistration,
};
