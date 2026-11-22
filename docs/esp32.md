# Guia do ESP32 (hardware e firmware)

## Materiais
- 1 × placa **ESP32** (DevKit com USB, ex.: ESP32-WROOM-32)
- 1 × sensor ultrassônico **HC-SR04**
- 4 jumpers fêmea-fêmea (ou protoboard + jumpers)
- 1 × cabo USB **de dados** (cabos só de carga não funcionam para gravar)
- *Recomendado:* divisor de tensão no pino ECHO (resistores de 1 kΩ e 2 kΩ), porque o HC-SR04 responde com 5 V e o ESP32 trabalha com 3,3 V. Na demonstração do projeto o ECHO foi ligado direto e funcionou, mas o divisor protege o ESP32.

## Ligações

| HC-SR04 | ESP32 |
|---|---|
| `VCC` | `5V` (pino **VIN**) |
| `GND` | `GND` |
| `TRIG` | `GPIO 5` (D5) |
| `ECHO` | `GPIO 18` (D18) — com divisor de tensão, se possível |

Os pinos podem ser trocados em `config.h` (`PIN_TRIG`, `PIN_ECHO`).

```
 HC-SR04                ESP32
 ┌──────┐
 │ VCC  ├──────────────  VIN (5V)
 │ TRIG ├──────────────  GPIO 5
 │ ECHO ├──[1k]──┬─────  GPIO 18
 │ GND  ├────────┼─────  GND
 └──────┘      [2k]
                 └─────  GND
```

## Preparar o Arduino IDE

1. Instale o **Arduino IDE** (1.8.19 ou 2.x): https://www.arduino.cc/en/software
2. Adicione o suporte ao ESP32: *Arquivo → Preferências → URLs adicionais para gerenciadores de placas* e cole  
   `https://espressif.github.io/arduino-esp32/package_esp32_index.json`  
   Depois *Ferramentas → Placa → Gerenciador de placas*, procure **esp32** (Espressif Systems) e instale.
3. Instale a biblioteca **PubSubClient** (Nick O'Leary): *Ferramentas → Gerenciar bibliotecas*, procure por `PubSubClient` e instale.
4. Se o Windows não reconhecer a placa, instale o driver USB-serial do chip da sua placa: **CP210x** (Silicon Labs) ou **CH340/CH9102** (WCH). Depois da instalação a porta **COM** aparece em *Ferramentas → Porta*.

## Configurar e gravar

1. Abra `firmware/bueiro_iot/bueiro_iot.ino`. O arquivo `config.h` abre numa aba ao lado.
2. Edite o `config.h`:

   | Linha | O que colocar |
   |---|---|
   | `WIFI_SSID` | nome da sua rede Wi-Fi (2,4 GHz — o ESP32 não usa 5 GHz) |
   | `WIFI_PASSWORD` | senha do Wi-Fi |
   | `MQTT_HOST` | **IP do computador** que roda a pilha. No Windows: `ipconfig` → "Endereço IPv4". Ex.: `192.168.0.100` |
   | `MQTT_PORT` | `1883` |
   | `BUEIRO_ID` | nome do dispositivo, ex.: `bueiro01` (vira parte dos tópicos) |
   | `TOPIC_BASE` | `bueiros` |
   | `PUBLISH_INTERVAL_MS` | `10000UL` (uma leitura a cada 10 s) |

3. *Ferramentas → Placa → ESP32 Arduino → **ESP32 Dev Module***, escolha a **Porta** e clique em **Upload** (seta →).
4. Se aparecer `Connecting........_____`, **segure o botão BOOT** da placa até começar a gravar "Writing at ...", e solte.
5. Abra *Ferramentas → Monitor Serial* e ajuste para **115200 baud**.

Saída esperada:
```
Conectando ao Wi-Fi NOME_DO_SEU_WIFI ....
Wi-Fi OK. IP: 192.168.0.57
Conectando ao broker 192.168.0.100:1883 (Wi-Fi -60 dBm) ... OK
[bueiros/bueiro01/nivel] {"id":"bueiro01","distancia_cm":62.4,"ts":"2026-11-20T21:27:56-03:00"}
```

## Libere o firewall (no computador da pilha)
O ESP32 conecta no computador pela porta **1883**. PowerShell **como administrador**:
```powershell
New-NetFirewallRule -DisplayName "MQTT bueiros 1883" -Direction Inbound -Protocol TCP -LocalPort 1883 -Action Allow -Profile Private
```
Se a rede estiver como *Pública*, troque `Private` por `Any`.

## O que o firmware faz
- Mede a distância com o HC-SR04 (velocidade do som 343 m/s) e usa a **mediana de 5 leituras** para reduzir ruído.
- Publica em `bueiros/{id}/nivel` o JSON `{"id":"bueiro01","distancia_cm":62.4,"ts":"2026-11-20T21:27:56-03:00"}` a cada 10 s (hora sincronizada por NTP).
- Publica `online` em `bueiros/{id}/status` ao conectar e configura a **Última Vontade (Last Will)** `offline` (retida), que o broker publica se o ESP32 cair.
- Reconecta sozinho ao Wi-Fi e ao broker.

## Sem o ESP32?
Use o simulador (README, passo 5): ele publica as mesmas mensagens no mesmo tópico.
