import 'dotenv/config';
import http from 'node:http';
import { createApp } from './app.js';
import { initSocket } from './socket.js';

const PORT = process.env.PORT || 8080;

const app = createApp();
const httpServer = http.createServer(app);
initSocket(httpServer);

httpServer.listen(PORT, () => {
  console.log(`famil-server listening on :${PORT}`);
});
