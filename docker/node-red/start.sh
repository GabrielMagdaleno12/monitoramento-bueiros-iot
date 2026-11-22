#!/bin/sh
# Prepara o Node-RED a cada inicio do container:
#  - copia o fluxo do projeto (somente na primeira vez, para nao apagar alteracoes feitas no editor)
#  - grava a credencial do InfluxDB (token) a partir do .env
# A chave do OpenWeatherMap chega como variavel de ambiente OPENWEATHER_KEY (lida pelo fluxo com env.get).
set -e

cp /opt/bueiros/settings.js /data/settings.js
[ -f /data/flows.json ] || cp /opt/bueiros/flows.json /data/flows.json

cat > /data/flows_cred.json <<EOT
{ "influx_cfg": { "token": "$INFLUX_TOKEN" } }
EOT

exec /usr/src/node-red/entrypoint.sh
