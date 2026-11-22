// testar-regras.js - executa os casos de teste das regras de negocio (artigo, secoes 3.9 e 4.6)
//
// Envia leituras ao broker, forca a previsao de chuva pelos botoes do Node-RED e compara o estado
// publicado em bueiros/{id}/risco com o esperado. Tambem mede a latencia e testa o aviso offline.
//
// Uso (com a pilha ligada):
//   node testar-regras.js [altura_do_bueiro_cm] [host]      ex.: node testar-regras.js 50 127.0.0.1
// A altura precisa ser a mesma do fluxo (BUEIRO_ALTURA_CM; padrao do repositorio: 50).
const mqtt = require('mqtt');
const http = require('http');
const ALT = Number(process.argv[2] || 50);
const HOST = process.argv[3] || '127.0.0.1';
const c = mqtt.connect('mqtt://' + HOST + ':1883');
const wait = ms => new Promise(r => setTimeout(r, ms));
const inject = id => new Promise(res => { const q = http.request({ host: HOST, port: 1880, path: '/inject/' + id, method: 'POST' }, r => { r.resume(); r.on('end', res); }); q.on('error', () => res()); q.end(); });
const dist = pct => Math.round(ALT * (1 - pct / 100) * 10) / 10;   // distancia que produz esse nivel
const got = {}, armed = {};
c.on('message', (t, m) => { const id = t.split('/')[1]; if (armed[id]) got[id] = { estado: m.toString(), t: Date.now() }; });

async function caso(id, d, esperado, rotulo) {
  armed[id] = false; delete got[id];
  c.subscribe('bueiros/' + id + '/risco');
  await wait(400);
  armed[id] = true;
  const t0 = Date.now();
  c.publish('bueiros/' + id + '/nivel', JSON.stringify({ id, distancia_cm: d, ts: new Date().toISOString() }));
  for (let i = 0; i < 40 && !got[id]; i++) await wait(50);
  const r = got[id];
  const obtido = r ? r.estado : 'descartada';
  const ok = obtido === esperado;
  console.log((ok ? 'OK    ' : 'FALHOU') + '  ' + rotulo.padEnd(38) + ' dist ' + String(d).padStart(6) + ' cm  esperado ' + esperado.padEnd(10) + ' obtido ' + obtido);
  return { ok, ms: r ? r.t - t0 : null };
}

(async () => {
  const res = [];
  console.log('Altura do bueiro: ' + ALT + ' cm | broker: ' + HOST + '\n');
  await inject('inj_seca'); await wait(1200);
  res.push(await caso('t_normal', dist(20), 'normal', 'Nivel baixo (20%)'));
  res.push(await caso('t_atencao', dist(60), 'atencao', 'Nivel medio (60%)'));
  res.push(await caso('t_critico', dist(83.3), 'critico', 'Nivel alto (83,3%)'));
  res.push(await caso('t_lim40', dist(40), 'atencao', 'Limite de 40%'));
  res.push(await caso('t_lim80', dist(80), 'critico', 'Limite de 80%'));
  res.push(await caso('t_subida', dist(10), 'normal', 'Subida rapida: leitura 1 (10%)'));
  res.push(await caso('t_subida', dist(30), 'atencao', 'Subida rapida: leitura 2 (30%)'));
  res.push(await caso('t_fora1', 500, 'descartada', 'Distancia acima da faixa do sensor'));
  res.push(await caso('t_fora2', 1, 'descartada', 'Distancia abaixo da faixa do sensor'));
  res.push(await caso('t_fora3', ALT + 50, 'normal', 'Distancia maior que a altura (bueiro vazio)'));
  await inject('inj_forte'); await wait(1200);
  res.push(await caso('t_chuva_normal', dist(20), 'atencao', 'Chuva forte + nivel baixo'));
  res.push(await caso('t_chuva_atencao', dist(60), 'critico', 'Chuva forte + nivel medio'));
  await inject('inj_seca'); await wait(800);

  const lat = [];
  for (let i = 0; i < 20; i++) { const r = await caso('t_lat' + i, dist(60), 'atencao', 'Latencia ' + (i + 1) + '/20'); if (r.ms != null) lat.push(r.ms); }

  // aviso offline (Last Will): conexao derrubada sem desconectar direito
  const w = mqtt.connect('mqtt://' + HOST + ':1883', { clientId: 't_off', will: { topic: 'bueiros/t_off/status', payload: 'offline', retain: true, qos: 1 } });
  await new Promise(r => w.on('connect', r));
  const s = mqtt.connect('mqtt://' + HOST + ':1883');
  let off = false; await new Promise(r => s.on('connect', r)); s.subscribe('bueiros/t_off/status');
  s.on('message', (t, m) => { if (m.toString() === 'offline') off = true; });
  await wait(300); w.stream.destroy(); await wait(1500);
  console.log((off ? 'OK    ' : 'FALHOU') + '  Queda do dispositivo (Last Will -> offline)');
  res.push({ ok: off });

  lat.sort((a, b) => a - b);
  const media = lat.reduce((a, b) => a + b, 0) / (lat.length || 1);
  const falhas = res.filter(r => !r.ok).length;
  console.log('\nLatencia (leitura -> estado publicado) em ' + lat.length + ' leituras: min ' + lat[0] + ' ms, mediana ' + lat[Math.floor(lat.length / 2)] + ' ms, media ' + media.toFixed(1) + ' ms, max ' + lat[lat.length - 1] + ' ms');
  console.log(falhas === 0 ? '\nTODOS OS CASOS PASSARAM' : '\n' + falhas + ' CASO(S) FALHARAM');
  process.exit(falhas ? 1 : 0);
})();
