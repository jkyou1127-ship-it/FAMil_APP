const fs = require('fs');
const path = require('path');
const db = require('../db');

let messaging = null;

function initFirebase() {
  if (messaging !== null) return messaging;

  const keyPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH
    ? path.resolve(process.env.FIREBASE_SERVICE_ACCOUNT_PATH)
    : path.join(__dirname, '..', '..', 'firebase-service-account.json');

  if (!fs.existsSync(keyPath)) {
    messaging = false; // Firebase not configured; push notifications are disabled.
    return messaging;
  }

  try {
    const { initializeApp, cert, getApps } = require('firebase-admin/app');
    const { getMessaging } = require('firebase-admin/messaging');
    const serviceAccount = JSON.parse(fs.readFileSync(keyPath, 'utf8'));
    const app = getApps().length ? getApps()[0] : initializeApp({ credential: cert(serviceAccount) });
    messaging = getMessaging(app);
    console.log('Firebase Cloud Messaging enabled.');
  } catch (err) {
    console.error('Firebase 초기화 실패, 푸시 알림이 비활성화됩니다:', err.message);
    messaging = false;
  }
  return messaging;
}

/**
 * 등록된 모든 기기에 푸시 알림을 보낸다. Firebase가 설정되어 있지 않으면 조용히 아무 일도 하지 않는다
 * (온라인 노크/매신저는 여전히 소켓으로 실시간 동작한다).
 */
async function sendPush(userId, { title, body, data } = {}) {
  const fcm = initFirebase();
  if (!fcm) return;

  const tokens = db.prepare('SELECT token FROM device_tokens WHERE user_id = ?').all(userId).map((r) => r.token);
  if (tokens.length === 0) return;

  const stringData = {};
  for (const [k, v] of Object.entries(data || {})) stringData[k] = String(v);

  try {
    const res = await fcm.sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: stringData,
      android: { priority: 'high' },
    });

    const invalidTokens = [];
    res.responses.forEach((r, i) => {
      if (!r.success && ['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'].includes(r.error && r.error.code)) {
        invalidTokens.push(tokens[i]);
      }
    });
    if (invalidTokens.length > 0) {
      const placeholders = invalidTokens.map(() => '?').join(',');
      db.prepare(`DELETE FROM device_tokens WHERE token IN (${placeholders})`).run(...invalidTokens);
    }
  } catch (err) {
    console.error('푸시 알림 전송 실패:', err.message);
  }
}

module.exports = { sendPush };
