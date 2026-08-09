/*
 * 로그인 자체가 안 될 때(비밀번호를 잊어버렸을 때) 쓰는 최후 수단.
 * PC에서 직접 실행해 DB의 비밀번호 해시를 바로 바꾼다 — 앱/로그인 없이도 동작한다.
 * 사용법: node src/scripts/reset-password.js <아이디> <새비밀번호>
 */
const bcrypt = require('bcryptjs');
const db = require('../db');

const [username, newPassword] = process.argv.slice(2);

if (!username || !newPassword) {
  console.error('사용법: node src/scripts/reset-password.js <아이디> <새비밀번호>');
  process.exit(1);
}
if (newPassword.length < 4) {
  console.error('비밀번호는 4자 이상이어야 합니다.');
  process.exit(1);
}

const user = db.prepare('SELECT id, username, display_name FROM users WHERE username = ?').get(username);
if (!user) {
  console.error(`"${username}" 아이디를 찾을 수 없습니다.`);
  process.exit(1);
}

const passwordHash = bcrypt.hashSync(newPassword, 10);
db.prepare('UPDATE users SET password_hash = ? WHERE id = ?').run(passwordHash, user.id);

console.log(`"${user.display_name}"(${user.username}) 계정의 비밀번호를 변경했습니다.`);
