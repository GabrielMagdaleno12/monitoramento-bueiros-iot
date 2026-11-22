# Modo nuvem (topologia do enunciado: cada elemento em um servidor diferente)

O enunciado exige que broker MQTT, Node-RED, banco de dados e Grafana **não rodem na mesma máquina**,
e que o banco seja **em nuvem**. Esta é a topologia final do projeto:

| Elemento | Onde roda | FQDN | IP (consulta DNS em 22/11/2026) | Porta |
|---|---|---|---|---|
| ESP32 + HC-SR04 | Dispositivo físico (Wi-Fi) | — | IP da rede local (DHCP) | — |
| Broker MQTT | HiveMQ público (nuvem) | `broker.hivemq.com` | 3.124.112.32 / 52.29.191.252 / 3.68.171.238 | 1883 |
| Node-RED | PC do grupo (rede local) | `localhost` / nome do PC | IP do PC na rede (ex.: 192.168.15.5) | 1880 |
| Banco InfluxDB | InfluxDB Cloud (AWS us-east-1) | `us-east-1-1.aws.cloud2.influxdata.com` | 34.196.233.7 | 443 (HTTPS) |
| Dashboards | Grafana Cloud | `silvercondor2940.grafana.net` | 104.18.12.97 (Cloudflare) | 443 (HTTPS) |
| API de previsão | OpenWeatherMap | `api.openweathermap.org` | resolvido pelo DNS | 443 (HTTPS) |

Os IPs de serviços em nuvem podem mudar; o que vale é o FQDN.

```
ESP32 --MQTT 1883--> broker.hivemq.com <--MQTT-- Node-RED (PC) --HTTPS--> InfluxDB Cloud <--Flux-- Grafana Cloud
                                                      |
                                                      +--HTTPS--> api.openweathermap.org
```

## Passo a passo

1. **InfluxDB Cloud** (plano grátis): crie a conta em https://cloud2.influxdata.com/signup, um bucket `bueiros`
   e um API token com leitura e escrita nesse bucket. Anote a URL do cluster e o nome da organização.
2. **Node-RED**: importe `node-red/flows-nuvem.json` (menu > Import). Abra o nó de configuração do InfluxDB
   (`InfluxDB`), confira a URL e a organização e cole o **token**. Faça Deploy.
   O broker já vem apontado para `broker.hivemq.com`.
3. **Grafana Cloud** (plano grátis): crie a conta em https://grafana.com. Em *Connections > Data sources > InfluxDB*:
   linguagem **Flux**, URL do cluster, organização, bucket padrão `bueiros` e o token. *Save & test*.
   Depois, *Dashboards > New > Import*, envie `grafana/bueiros-dashboard-cloud.json` e escolha esse data source.
4. **ESP32**: em `firmware/bueiro_iot/config.h` use `MQTT_HOST "broker.hivemq.com"` e `MQTT_PORT 1883`.
5. **Teste sem hardware**: `node windows-sem-docker/broker/simular.js` aponta para o broker local; para o público,
   publique em `bueiros/bueiro01/nivel` o JSON `{"id":"bueiro01","distancia_cm":25}` com qualquer cliente MQTT.

## Abrir o projeto em outro computador (só o Node-RED precisa de instalação)

Broker, banco e Grafana já estão na nuvem; em outro PC basta instalar o Node-RED:

1. Instale o Node.js LTS (https://nodejs.org).
2. No PowerShell: `npm install -g node-red node-red-contrib-influxdb` e depois `node-red`. Abra http://localhost:1880.
3. Menu > Import > envie `node-red/flows-nuvem.json`. No nó de configuração **InfluxDB**, cole o token e confira URL e organização. Deploy.
4. Previsão de chuva real: antes de rodar `node-red`, defina a chave: `$env:OPENWEATHER_KEY="SUA_CHAVE"` (sem a chave o fluxo usa previsão simulada).
5. Altura do bueiro, local e coordenadas: duplo clique na aba do fluxo > Variáveis de ambiente (padrão: 50 cm, Mackenzie-SP).
6. O ESP32 e o Grafana Cloud não mudam; qualquer PC com internet roda o Node-RED. Só **um** Node-RED deve ficar ligado por vez (dois gravariam leituras em duplicidade).

Alternativa com Docker: a pasta docker/ do repositório já traz o Node-RED pronto.

## Observações

- O HiveMQ público não tem senha: qualquer pessoa pode ler ou publicar nos tópicos `bueiros/...`. É aceitável
  para um protótipo; em produção use um broker com usuário, senha e TLS.
- O token do InfluxDB **nunca** vai para o repositório; ele é digitado no Node-RED e no Grafana.
- A pilha local (Docker ou Windows sem Docker) continua disponível para rodar tudo offline.
