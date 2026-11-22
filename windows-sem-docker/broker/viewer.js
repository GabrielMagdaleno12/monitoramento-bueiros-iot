// Serve a pagina "Monitor MQTT" em http://localhost:8085 (usa o WebSocket do broker, porta 9001)
const http = require('http');
const fs = require('fs');
const path = require('path');
http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
  fs.createReadStream(path.join(__dirname, 'viewer', 'index.html')).pipe(res);
}).listen(8085, '127.0.0.1', () => console.log('Monitor MQTT em http://localhost:8085'));
