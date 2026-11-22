# Solução de problemas

## Pilha de software

| Sintoma | Causa provável | O que fazer |
|---|---|---|
| `docker compose up` diz que a porta já está em uso | outro programa usa 1883, 1880, 8086, 3000 ou 8085 | feche o programa, ou troque a porta à esquerda em `docker-compose.yml` (ex.: `"3001:3000"`) |
| Docker: `error during connect` / engine não responde | Docker Desktop fechado | abra o Docker Desktop e espere "Engine running" |
| Um serviço fica reiniciando | erro de configuração | `docker compose logs nodered` (ou `influxdb`, `grafana`, `mosquitto`) mostra o motivo |
| Quer recomeçar do zero | — | `docker compose down -v` e depois `docker compose up -d --build` |
| Grafana abre mas todos os painéis dizem "No data" | ainda não chegou nenhuma leitura, ou intervalo curto | rode o simulador (README, passo 5) e escolha *Last 1 hour* no canto superior direito |
| Grafana: erro de datasource / 401 | token do Grafana diferente do token do InfluxDB | confira `INFLUX_TOKEN` no `.env` e rode `docker compose up -d --force-recreate` |
| Node-RED: nó do InfluxDB com erro | token errado | mesmo `INFLUX_TOKEN` do `.env` |
| Grafana sempre em "normal" / 0 % | distância medida maior que a altura do bueiro (50 cm por padrão) = bueiro vazio | aproxime um objeto do sensor (menos de 50 cm) ou ajuste `BUEIRO_ALTURA_CM` |
| Node-RED: aviso "Leitura fora da faixa do sensor" | distância < 2 cm ou > 400 cm | normal — a leitura é descartada de propósito |
| Chuva sempre 20 % | falta a chave do OpenWeatherMap | README, passo 7 |
| OpenWeatherMap: aviso "(401)" | chave errada ou ainda não ativada | espere até 2 h após criar a chave e confira se copiou inteira |
| Monitor MQTT diz "desconectado" | broker fora do ar | `docker compose ps` / rode `INICIAR.ps1` |
| Aviso "O servidor está executando um conjunto de fluxos mais recente" no Node-RED | a tela estava desatualizada | clique em **Cancelar**, recarregue a página (F5) e refaça a alteração |

## ESP32

| Sintoma | Causa provável | O que fazer |
|---|---|---|
| Upload: `Failed to connect ... No serial data received` | cabo só de carga, driver, modo de boot | use outro cabo USB de dados; instale o driver CP210x/CH340; segure **BOOT** durante o `Connecting...` |
| A porta COM não aparece | driver ausente | instale o driver do chip da sua placa e reconecte |
| Serial Monitor com caracteres estranhos | velocidade errada | selecione **115200** baud |
| `Falha no Wi-Fi, reiniciando...` | senha errada ou rede 5 GHz | confira `WIFI_SSID` / `WIFI_PASSWORD`; use rede 2,4 GHz |
| `falhou (rc=-2)` na linha do broker | ESP32 não alcança o broker | confira `MQTT_HOST` (IP **atual** do PC com `ipconfig`), firewall da porta 1883 e se ESP32 e PC estão na **mesma rede** |
| Conecta e cai de tempos em tempos | alimentação ou Wi-Fi fracos | cabo/fonte USB melhores; aproxime do roteador |
| Distância sempre 0 ou muito instável | ligação do sensor | confira VCC em 5 V, GND comum e TRIG/ECHO nos pinos do `config.h` |

## Descobrir o IP do computador
```powershell
ipconfig
```
Use o "Endereço IPv4" do adaptador Wi-Fi/Ethernet (ex.: `192.168.0.100`). Esse IP pode mudar quando o roteador reinicia — se o ESP32 parar de conectar, confira de novo e regrave.
