# Regras de negócio, tópicos MQTT e dados

## Tópicos MQTT

| Tópico | Quem publica | Conteúdo |
|---|---|---|
| `bueiros/{id}/nivel` | ESP32 | JSON `{"id","distancia_cm","ts"}` a cada 10 s |
| `bueiros/{id}/status` | ESP32 (e broker, via Last Will) | `online` / `offline` (retido) |
| `bueiros/{id}/risco` | Node-RED | `normal` / `atencao` / `critico` (retido) |

## Cálculo do nível

```
nivel_cm  = altura_do_bueiro - distancia_cm        (altura padrão: 50 cm, variável BUEIRO_ALTURA_CM)
nivel_pct = nivel_cm / altura_do_bueiro * 100
```

| nivel_pct | Estado base |
|---|---|
| < 40 % | `normal` |
| 40 % a < 80 % | `atencao` |
| ≥ 80 % | `critico` |

## Ajustes sobre o estado base (cada um sobe **um** nível, no máximo até `critico`)

1. **Chuva prevista:** probabilidade ≥ 70 % **ou** volume ≥ 2,5 mm (OpenWeatherMap, consultado a cada 10 min; usa o intervalo de 3 h mais próximo do horário atual).
2. **Subida rápida:** aumento ≥ 15 pontos percentuais em 5 minutos.

## Validações
- Distância fora de **2 a 400 cm** (faixa do HC-SR04) → leitura **descartada**.
- Distância maior que a altura do bueiro → nível 0 % (bueiro vazio), estado normal.
- Previsão de chuva com mais de **1 hora** → ignorada.
- Falha na API do tempo → mantém o último valor válido e registra aviso.
- Dispositivo `offline` → evento registrado no Node-RED.
- Latência (hora da medição → gravação) acima de 2 s gera aviso.

## InfluxDB (organização `bueiros`, bucket `bueiros`)

**measurement `nivel_bueiro`** — tags: `bueiro_id`, `local` · campos: `distancia_cm`, `nivel_cm`, `nivel_pct`, `estado`

**measurement `previsao_chuva`** — tag: `local` · campos: `prob_chuva_pct`, `chuva_mm`

Consulta de exemplo (Flux), para colar no *Data Explorer → Script Editor* do InfluxDB:
```flux
from(bucket: "bueiros")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "nivel_bueiro" and r._field == "nivel_pct")
```

## Dashboard do Grafana
Atualiza a cada 10 s. Painéis: nível ao longo do tempo (com linhas de limite em 40 % e 80 %), status de alerta atual, gauge do nível, chuva prevista × nível, histórico de estados, contagem de eventos críticos e tabela das últimas leituras.

O arquivo importável está em `grafana/bueiros-dashboard.json` (*Dashboards → New → Import*), usando um datasource InfluxDB chamado **InfluxDB-Bueiros** (uid `influx-bueiros`, linguagem Flux, org `bueiros`, bucket `bueiros`).

## Token do InfluxDB
No Docker e na instalação Windows desta entrega, um único token (`INFLUX_TOKEN`) serve ao Node-RED (gravação) e ao Grafana (leitura), para simplificar a reprodução. Em um ambiente real, crie **dois tokens**: um só de escrita para o Node-RED e um **somente leitura** para o Grafana:

```powershell
docker compose exec influxdb influx auth create --org bueiros --read-bucket <ID_DO_BUCKET> --description grafana-leitura
```
(o ID do bucket: `docker compose exec influxdb influx bucket list`). Troque o token em `docker/grafana/provisioning/datasources/influxdb.yml`.
