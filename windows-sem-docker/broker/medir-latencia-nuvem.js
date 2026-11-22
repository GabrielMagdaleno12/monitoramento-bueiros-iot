const mqtt = require('mqtt');
const c = mqtt.connect('mqtt://broker.hivemq.com:1883', { clientId: 'lat-nuvem-' + Math.random().toString(16).slice(2, 8) });
const id = 'latnuvem'; const lat = []; let t0, n = 0;
c.on('connect', () => { c.subscribe('bueiros/' + id + '/risco', () => setTimeout(send, 800)); });
function send() { t0 = Date.now(); c.publish('bueiros/' + id + '/nivel', JSON.stringify({ id, distancia_cm: 20 + n, ts: new Date().toISOString() }), { qos: 1 }); }
c.on('message', () => { lat.push(Date.now() - t0); n++; if (n < 20) setTimeout(send, 600); else fim(); });
function fim() { lat.sort((a, b) => a - b); const m = lat.reduce((a, b) => a + b, 0) / lat.length;
  console.log('n', lat.length, 'min', lat[0], 'mediana', lat[10], 'media', m.toFixed(0), 'max', lat[19], JSON.stringify(lat)); process.exit(0); }
setTimeout(() => { console.log('timeout; parcial', JSON.stringify(lat)); process.exit(1); }, 60000);
