# Instalação no Windows sem Docker (Opção B)

Use este caminho se não puder instalar o Docker. É o mesmo ambiente usado na demonstração em vídeo do projeto.

## Resumo (2 comandos)

Com o **Node.js 18+** instalado (https://nodejs.org), no PowerShell, dentro de `windows-sem-docker`:

```powershell
powershell -ExecutionPolicy Bypass -File .\INSTALAR.ps1      # uma única vez
powershell -ExecutionPolicy Bypass -File .\INICIAR.ps1       # sempre que ligar o PC
```

## O que o `INSTALAR.ps1` faz

| Passo | Ação |
|---|---|
| 1 | confere o Node.js |
| 2 | instala o broker MQTT (**Aedes**, em Node.js) e a página Monitor MQTT (`npm install` em `broker/`) |
| 3 | instala o **Node-RED 5.0.10** e o nó `node-red-contrib-influxdb` em `runtime/node-red` |
| 4 | baixa **InfluxDB 2.7.10**, **influx CLI 2.7.5** e **Grafana 11.3.1** (zips oficiais) para `runtime/` |
| 5 | liga o InfluxDB e cria usuário, organização `bueiros`, bucket `bueiros` e o token |
| 6 | grava o fluxo (`node-red/flows.json`) e a credencial do InfluxDB no Node-RED |
| 7 | grava o datasource e o dashboard do Grafana (provisionamento automático) |

Tudo fica dentro de `windows-sem-docker/runtime/` (ignorado pelo Git). Para desinstalar, apague essa pasta.

Parâmetros opcionais do `INSTALAR.ps1`: `-InfluxUser`, `-InfluxPassword`, `-InfluxToken` e `-OpenWeatherKey`.
Login do InfluxDB (http://localhost:8086): usuário `bueiros`, senha `bueiros-senha-123` (se não mudou).

## O que o `INICIAR.ps1` liga

| Serviço | Porta | Log (em `runtime/logs`) |
|---|---|---|
| Broker MQTT (Aedes) | 1883 (TCP, para o ESP32) e 9001 (WebSocket) | `broker.out.log` |
| Monitor MQTT | 8085 | `viewer.out.log` |
| InfluxDB | 8086 | `influxd.out.log` |
| Node-RED | 1880 | `nodered.out.log` |
| Grafana | 3000 | `grafana.out.log` |

O script só liga o que ainda não estiver rodando, então pode ser executado de novo sem problema.

## Parar tudo
```powershell
Get-Process node, influxd, grafana-server -ErrorAction SilentlyContinue | Stop-Process
```

## Chave do OpenWeatherMap
```powershell
powershell -ExecutionPolicy Bypass -File .\DEFINIR-CHAVE.ps1 -Chave "SUA_CHAVE"
```
Guarda a chave em `runtime/openweather.key` e reinicia o Node-RED. O fluxo lê a chave da variável de ambiente `OPENWEATHER_KEY`.

## Firewall
Para o ESP32 alcançar o broker, libere a porta 1883 (PowerShell **como administrador**):
```powershell
New-NetFirewallRule -DisplayName "MQTT bueiros 1883" -Direction Inbound -Protocol TCP -LocalPort 1883 -Action Allow -Profile Private
```

## Simulador (sem ESP32)
```powershell
cd broker
node simular.js            # normal -> atencao -> critico -> normal
```

## Instalação manual (se o script falhar)
1. Instale Node.js 18+.
2. `cd windows-sem-docker/broker && npm install` e `node broker.js` (broker na 1883).
3. Instale o Node-RED: `npm install node-red@5.0.10 node-red-contrib-influxdb@0.7.0`; copie `docker/node-red/settings.js` e `node-red/flows.json` para a pasta de dados e rode `node node_modules/node-red/red.js --userDir <pasta> --settings <pasta>/settings.js`.
4. Baixe e rode o InfluxDB 2.7 (`influxd.exe`); com o `influx.exe`: `influx setup --username bueiros --password <senha> --org bueiros --bucket bueiros --token <token> --force`.
5. No Node-RED, abra o nó de configuração **InfluxDB** e informe o token.
6. Baixe o Grafana 11.3.1, crie o datasource InfluxDB (Flux, org `bueiros`, bucket `bueiros`, uid `influx-bueiros`, token) e importe `grafana/bueiros-dashboard.json`.
