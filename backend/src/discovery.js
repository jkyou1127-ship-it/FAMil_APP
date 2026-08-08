const dgram = require('dgram');

const DISCOVERY_PORT = 41234;
const MAGIC_REQUEST = 'FAMIL_APP_DISCOVER';

// 같은 Wi-Fi 안에서 폰 앱이 이 PC의 IP를 직접 입력하지 않아도 서버를 찾을 수 있도록,
// UDP 브로드캐스트 탐색 요청에 "나 여기 있다"고 응답한다.
function startDiscoveryResponder(httpPort) {
  const socket = dgram.createSocket('udp4');

  socket.on('message', (msg, rinfo) => {
    if (msg.toString() !== MAGIC_REQUEST) return;
    const reply = Buffer.from(JSON.stringify({ service: 'famil-app', port: httpPort }));
    socket.send(reply, rinfo.port, rinfo.address);
  });

  socket.on('error', (err) => {
    console.error('탐색 응답 소켓 오류 (자동 감지 기능만 비활성화됨):', err.message);
  });

  socket.bind(DISCOVERY_PORT);
  return socket;
}

module.exports = { startDiscoveryResponder, DISCOVERY_PORT, MAGIC_REQUEST };
