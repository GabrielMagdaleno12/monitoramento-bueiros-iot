# INICIAR.ps1 - liga broker MQTT, Monitor MQTT, InfluxDB, Node-RED e Grafana (execute apos o INSTALAR.ps1)
#   powershell -ExecutionPolicy Bypass -File .\INICIAR.ps1
$root = $PSScriptRoot
$rt   = Join-Path $root 'runtime'
if (-not (Test-Path $rt)) { Write-Host 'Rode primeiro o INSTALAR.ps1.' -ForegroundColor Red; exit 1 }

function Test-Port($p) { try { (Test-NetConnection 127.0.0.1 -Port $p -WarningAction SilentlyContinue).TcpTestSucceeded } catch { $false } }
function Iniciar($nome, $porta, [scriptblock]$acao) { if (Test-Port $porta) { Write-Host "$nome ja esta rodando (porta $porta)" } else { Write-Host "Iniciando $nome ..."; & $acao } }

Iniciar 'Broker MQTT' 1883 {
  Start-Process node -ArgumentList "`"$root\broker\broker.js`"" -WorkingDirectory "$root\broker" -WindowStyle Hidden -RedirectStandardOutput "$rt\logs\broker.out.log" -RedirectStandardError "$rt\logs\broker.err.log"
  Start-Sleep -Seconds 3
}
Iniciar 'Monitor MQTT' 8085 {
  Start-Process node -ArgumentList "`"$root\broker\viewer.js`"" -WorkingDirectory "$root\broker" -WindowStyle Hidden -RedirectStandardOutput "$rt\logs\viewer.out.log" -RedirectStandardError "$rt\logs\viewer.err.log"
}
Iniciar 'InfluxDB' 8086 {
  $influxd = (Get-ChildItem "$rt\influxdb" -Recurse -Filter influxd.exe | Select-Object -First 1).FullName
  Start-Process $influxd -ArgumentList '--bolt-path', "`"$rt\influxdb-data\influxd.bolt`"", '--engine-path', "`"$rt\influxdb-data\engine`"", '--http-bind-address', '127.0.0.1:8086' -WindowStyle Hidden -RedirectStandardOutput "$rt\logs\influxd.out.log" -RedirectStandardError "$rt\logs\influxd.err.log"
  Start-Sleep -Seconds 8
}
Iniciar 'Node-RED' 1880 {
  $nr = "$rt\node-red"; $u = "$rt\node-red-data"
  # chave do OpenWeatherMap (opcional): lida de runtime\openweather.key e passada como variavel de ambiente
  if (Test-Path "$rt\openweather.key") { $env:OPENWEATHER_KEY = (Get-Content "$rt\openweather.key" -Raw).Trim() }
  Start-Process node -ArgumentList "`"$nr\node_modules\node-red\red.js`"", '--userDir', "`"$u`"", '--settings', "`"$u\settings.js`"" -WorkingDirectory $nr -WindowStyle Hidden -RedirectStandardOutput "$rt\logs\nodered.out.log" -RedirectStandardError "$rt\logs\nodered.err.log"
}
Iniciar 'Grafana' 3000 {
  $g = (Get-ChildItem "$rt\grafana" -Recurse -Filter grafana-server.exe | Select-Object -First 1).Directory.Parent.FullName
  $env:GF_PATHS_DATA = "$rt\grafana-data"; $env:GF_PATHS_LOGS = "$rt\logs"
  $env:GF_AUTH_ANONYMOUS_ENABLED = 'true'; $env:GF_AUTH_ANONYMOUS_ORG_ROLE = 'Admin'; $env:GF_AUTH_DISABLE_LOGIN_FORM = 'true'
  $env:GF_SERVER_HTTP_ADDR = '127.0.0.1'; $env:GF_SERVER_HTTP_PORT = '3000'; $env:GF_DASHBOARDS_MIN_REFRESH_INTERVAL = '5s'
  $env:GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH = "$rt\grafana-dashboards\bueiros.json"
  $env:GF_ANALYTICS_REPORTING_ENABLED = 'false'; $env:GF_ANALYTICS_CHECK_FOR_UPDATES = 'false'
  Start-Process "$g\bin\grafana-server.exe" -ArgumentList '--homepath', "`"$g`"" -WorkingDirectory $g -WindowStyle Hidden -RedirectStandardOutput "$rt\logs\grafana.out.log" -RedirectStandardError "$rt\logs\grafana.err.log"
}

Write-Host ''
Write-Host 'Pronto! Abra:' -ForegroundColor Green
Write-Host '  Monitor MQTT : http://localhost:8085'
Write-Host '  Node-RED     : http://localhost:1880'
Write-Host '  InfluxDB     : http://localhost:8086'
Write-Host '  Grafana      : http://localhost:3000/d/bueiros-monitoramento'
Write-Host 'Broker MQTT na porta 1883 (use o IP deste PC no config.h do ESP32).'
