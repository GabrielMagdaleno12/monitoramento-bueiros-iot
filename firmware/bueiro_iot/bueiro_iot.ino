/*
  Monitoramento Inteligente de Bueiros via IoT
  Dispositivo físico: ESP32 + sensor ultrassônico HC-SR04

  O que faz:
  - Mede a distância até a superfície da água (HC-SR04, mediana de 5 medições).
  - Publica a leitura em JSON no tópico {TOPIC_BASE}/{BUEIRO_ID}/nivel
       {"id":"bueiro01","distancia_cm":42.5,"ts":"2026-11-17T23:23:10-03:00"}
  - Publica "online"/"offline" em {TOPIC_BASE}/{BUEIRO_ID}/status.
       O "offline" é enviado pelo próprio broker (Last Will) se o ESP32 perder a conexão.

  Bibliotecas necessárias:
  - Placa "esp32" (Espressif Systems)
  - PubSubClient (Nick O'Leary)
*/

#include <WiFi.h>
#include <PubSubClient.h>
#include <time.h>
#include "config.h"

WiFiClient wifiClient;
PubSubClient mqtt(wifiClient);

char topicNivel[96];
char topicStatus[96];
char clientId[48];

unsigned long lastPublish = 0;
unsigned long lastMqttAttempt = 0;

// ---------- Sensor ----------
float readDistanceOnce() {
  digitalWrite(PIN_TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(PIN_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(PIN_TRIG, LOW);

  unsigned long dur = pulseIn(PIN_ECHO, HIGH, 30000UL);  // timeout de 30 ms (~5 m)
  if (dur == 0) return NAN;
  return dur * 0.0343f / 2.0f;  // velocidade do som: 343 m/s = 0,0343 cm/µs
}

// Mediana de 5 medições para reduzir ruído. Retorna NAN se houver menos de 3 válidas.
float readDistanceMedian() {
  float v[5];
  int n = 0;
  for (int i = 0; i < 5; i++) {
    float d = readDistanceOnce();
    if (!isnan(d)) v[n++] = d;
    delay(60);
  }
  if (n < 3) return NAN;

  // Ordenação por inserção
  for (int i = 1; i < n; i++) {
    float k = v[i];
    int j = i - 1;
    while (j >= 0 && v[j] > k) {
      v[j + 1] = v[j];
      j--;
    }
    v[j + 1] = k;
  }
  return v[n / 2];
}

// ---------- Rede ----------
void connectWifi() {
  Serial.printf("Conectando ao Wi-Fi %s ", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);  // desliga economia de energia do Wi-Fi: evita quedas de conexão com o broker
  WiFi.setAutoReconnect(true);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  unsigned long t0 = millis();
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
    if (millis() - t0 > 30000) {  // 30 s sem conectar: reinicia e tenta de novo
      Serial.println("\nFalha no Wi-Fi, reiniciando...");
      ESP.restart();
    }
  }
  Serial.printf("\nWi-Fi OK. IP: %s\n", WiFi.localIP().toString().c_str());
  configTime(-3 * 3600, 0, "pool.ntp.org", "time.google.com");  // horário de Brasília (UTC-3)
}

bool connectMqtt() {
  Serial.printf("Conectando ao broker %s:%d (Wi-Fi %d dBm) ... ", MQTT_HOST, MQTT_PORT, WiFi.RSSI());
  wifiClient.stop();  // fecha qualquer socket antigo antes de tentar de novo
  bool ok;
  if (strlen(MQTT_USER) > 0) {
    ok = mqtt.connect(clientId, MQTT_USER, MQTT_PASSWORD, topicStatus, 1, true, "offline");
  } else {
    ok = mqtt.connect(clientId, NULL, NULL, topicStatus, 1, true, "offline");
  }

  if (ok) {
    Serial.println("OK");
    mqtt.publish(topicStatus, "online", true);  // mensagem retida
  } else {
    Serial.printf("falhou (rc=%d)\n", mqtt.state());
  }
  return ok;
}

bool timestampISO(char *buf, size_t n) {
  struct tm t;
  if (!getLocalTime(&t, 0)) return false;  // NTP ainda não sincronizou
  strftime(buf, n, "%Y-%m-%dT%H:%M:%S-03:00", &t);
  return true;
}

// ---------- Setup e Loop ----------
void setup() {
  Serial.begin(115200);
  delay(200);

  // Configuração dos pinos do HC-SR04
  pinMode(PIN_TRIG, OUTPUT);
  pinMode(PIN_ECHO, INPUT);
  digitalWrite(PIN_TRIG, LOW);

  // Monta tópicos e Client ID único
  snprintf(topicNivel, sizeof(topicNivel), "%s/%s/nivel", TOPIC_BASE, BUEIRO_ID);
  snprintf(topicStatus, sizeof(topicStatus), "%s/%s/status", TOPIC_BASE, BUEIRO_ID);
  snprintf(clientId, sizeof(clientId), "esp32-%s-%04X", BUEIRO_ID, (uint16_t)(ESP.getEfuseMac() & 0xFFFF));

  connectWifi();

  mqtt.setServer(MQTT_HOST, MQTT_PORT);
  mqtt.setBufferSize(256);
  mqtt.setKeepAlive(30);       // avisa o broker a cada 30 s que a conexão está viva
  mqtt.setSocketTimeout(10);   // espera até 10 s pela resposta do broker
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    connectWifi();
  }

  if (!mqtt.connected()) {
    unsigned long now = millis();
    if (now - lastMqttAttempt >= 5000UL) {
      lastMqttAttempt = now;
      connectMqtt();
    }
    return;
  }

  mqtt.loop();

  unsigned long now = millis();
  if (now - lastPublish >= PUBLISH_INTERVAL_MS) {
    lastPublish = now;

    float dist = readDistanceMedian();
    if (isnan(dist)) {
      Serial.println("Leitura invalida do HC-SR04 (sem eco suficiente).");
      return;
    }

    char ts[32];
    if (!timestampISO(ts, sizeof(ts))) {
      strcpy(ts, "1970-01-01T00:00:00-03:00");
    }

    char payload[160];
    snprintf(payload, sizeof(payload),
             "{\"id\":\"%s\",\"distancia_cm\":%.1f,\"ts\":\"%s\"}",
             BUEIRO_ID, dist, ts);

    if (mqtt.publish(topicNivel, payload)) {
      Serial.printf("[%s] %s\n", topicNivel, payload);
    } else {
      Serial.println("Erro ao publicar payload MQTT.");
    }
  }
}
