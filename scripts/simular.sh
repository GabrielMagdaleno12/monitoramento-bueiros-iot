#!/bin/sh
# Simula o ESP32 (sem hardware) quando a pilha esta rodando com Docker (Linux / macOS / Git Bash).
# Uso:  sh scripts/simular.sh            ou          sh scripts/simular.sh 45 35 25 8
# Com altura do bueiro = 50 cm:  45 cm -> 10% (normal) | 25 cm -> 50% (atencao) | 8 cm -> 84% (critico)
[ $# -eq 0 ] && set -- 45 35 25 8 25 45
for d in "$@"; do
  ts=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
  json="{\"id\":\"simulado01\",\"distancia_cm\":$d,\"ts\":\"$ts\"}"
  echo "$json" | docker compose exec -T mosquitto mosquitto_pub -t bueiros/simulado01/nivel -q 1 -s
  echo "publicado: $json"
  sleep 5
done
