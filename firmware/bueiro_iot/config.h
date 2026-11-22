#ifndef CONFIG_H
#define CONFIG_H

// ---------- Wi-Fi ----------
#define WIFI_SSID           "NOME_DO_SEU_WIFI"
#define WIFI_PASSWORD       "SUA_SENHA_AQUI"

// ---------- Broker MQTT ----------
#define MQTT_HOST           "broker.hivemq.com"  // broker MQTT publico na nuvem (HiveMQ). Para a pilha local, use o IP do PC
#define MQTT_PORT           1883
#define MQTT_USER           ""                  // deixe vazio se o broker não exigir autenticação
#define MQTT_PASSWORD       ""

// ---------- Identificação do Dispositivo ----------
#define TOPIC_BASE          "bueiros"
#define BUEIRO_ID           "bueiro01"

// ---------- Pinos HC-SR04 ----------
#define PIN_TRIG            5   // GPIO 5 (D5)
#define PIN_ECHO            18  // GPIO 18 (D18)

// ---------- Intervalo de Publicação ----------
#define PUBLISH_INTERVAL_MS 10000UL  // publica a cada 10 segundos

#endif
