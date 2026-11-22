// Broker MQTT local do projeto Monitoramento de Bueiros (Aedes) - substitui o Mosquitto quando nao se usa Docker
// TCP 1883 (ESP32 e Node-RED) e WebSocket 9001 (pagina Monitor MQTT)
const { Aedes } = require('aedes');
const { createServer } = require('aedes-server-factory');

(async () => {
  const aedes = await Aedes.createBroker();
  const hora = () => new Date().toLocaleTimeString('pt-BR');

  aedes.on('client', (c) => console.log(hora(), 'conectou   ', c ? c.id : '?'));
  aedes.on('clientDisconnect', (c) => console.log(hora(), 'desconectou', c ? c.id : '?'));
  aedes.on('publish', (p, c) => {
    if (c && !String(p.topic).startsWith('$SYS')) console.log(hora(), p.topic, p.payload.toString().slice(0, 140));
  });

  const tcp = createServer(aedes);
  tcp.listen(1883, '0.0.0.0', () => console.log(hora(), 'MQTT TCP escutando em 0.0.0.0:1883'));

  const ws = createServer(aedes, { ws: true });
  ws.listen(9001, '127.0.0.1', () => console.log(hora(), 'MQTT WebSocket escutando em 127.0.0.1:9001'));
})().catch((e) => { console.error('erro ao subir broker', e); process.exit(1); });
