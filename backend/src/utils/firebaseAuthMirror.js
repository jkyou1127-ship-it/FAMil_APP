const fs = require('fs');
const path = require('path');

// PC 백엔드가 꺼져 있을 때도 Firebase 모드로 똑같은 아이디/비밀번호로 로그인할
// 수 있도록, 계정이 생성/변경/삭제될 때마다 Firebase Authentication에도 같은
// 계정을 반영해둔다. push.js의 FCM 초기화와 동일한 서비스 계정 파일을 쓰고,
// 같은 방식으로 "설정 안 돼 있으면 조용히 비활성화"한다 — PC 모드 로그인
// 자체에는 영향이 없다 (Firebase 모드 로그인만 그동안 최신 상태가 아니게 된다).
let authAdmin = null;

function initFirebaseAuth() {
  if (authAdmin !== null) return authAdmin;

  const keyPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH
    ? path.resolve(process.env.FIREBASE_SERVICE_ACCOUNT_PATH)
    : path.join(__dirname, '..', '..', 'firebase-service-account.json');

  if (!fs.existsSync(keyPath)) {
    authAdmin = false;
    return authAdmin;
  }

  try {
    const { initializeApp, cert, getApps } = require('firebase-admin/app');
    const { getAuth } = require('firebase-admin/auth');
    const serviceAccount = JSON.parse(fs.readFileSync(keyPath, 'utf8'));
    const app = getApps().length ? getApps()[0] : initializeApp({ credential: cert(serviceAccount) });
    authAdmin = getAuth(app);
  } catch (err) {
    console.error('Firebase Auth 초기화 실패, 계정 미러링이 비활성화됩니다:', err.message);
    authAdmin = false;
  }
  return authAdmin;
}

// Firebase Authentication은 이메일 형식의 아이디를 요구하므로, 로그인용
// username을 고정 도메인의 이메일로 바꿔서 쓴다 (실제 메일함은 아니다).
function syntheticEmail(username) {
  return `${username}@famil-app.local`;
}

/** 새 계정을 Firebase Authentication에도 만든다. 실패해도 조용히 무시한다. */
async function mirrorCreate(username, password, displayName) {
  const auth = initFirebaseAuth();
  if (!auth) return null;
  try {
    const record = await auth.createUser({ email: syntheticEmail(username), password, displayName });
    return record.uid;
  } catch (err) {
    console.error('Firebase Auth 계정 생성 미러링 실패:', err.message);
    return null;
  }
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

async function mirrorUsernameChange(firebaseUid, newUsername) {
  const auth = initFirebaseAuth();
  if (!auth || !firebaseUid) return;
  try {
    await auth.updateUser(firebaseUid, { email: syntheticEmail(newUsername) });
  } catch (err) {
    console.error('Firebase Auth 아이디 변경 미러링 실패:', err.message);
  }
}

async function mirrorDelete(firebaseUid) {
  const auth = initFirebaseAuth();
  if (!auth || !firebaseUid) return;
  try {
    await auth.deleteUser(firebaseUid);
  } catch (err) {
    console.error('Firebase Auth 계정 삭제 미러링 실패:', err.message);
  }
}

module.exports = {
  mirrorCreate,
  mirrorPasswordChange,
  mirrorUsernameChange,
  mirrorDelete,
  syntheticEmail,
};
