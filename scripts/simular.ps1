# Simula o ESP32 (sem hardware) quando a pilha esta rodando com Docker.
# Publica distancias do sensor no topico bueiros/simulado01/nivel a cada 5 s.
# Uso:  powershell -ExecutionPolicy Bypass -File .\scripts\simular.ps1
#       powershell -ExecutionPolicy Bypass -File .\scripts\simular.ps1 -Distancias 45,35,25,8
# Com altura do bueiro = 50 cm:  45 cm -> 10% (normal) | 25 cm -> 50% (atencao) | 8 cm -> 84% (critico)
param([int[]]$Distancias = @(45, 35, 25, 8, 25, 45))
foreach ($d in $Distancias) {
  $ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
  $json = '{"id":"simulado01","distancia_cm":' + $d + ',"ts":"' + $ts + '"}'
  $json | docker compose exec -T mosquitto mosquitto_pub -t bueiros/simulado01/nivel -q 1 -s
  Write-Host "publicado: $json"
  Start-Sleep -Seconds 5
}
