# INSTALAR.ps1 - instala e configura TODA a pilha no Windows, SEM Docker (executar uma unica vez)
#
#   Broker MQTT (Aedes) + Node-RED + InfluxDB 2.7 + Grafana 11.3
#
# Pre-requisito: Node.js 18 ou mais novo (https://nodejs.org). Conexao com a internet (baixa ~250 MB).
# Uso (PowerShell, dentro da pasta windows-sem-docker):
#   powershell -ExecutionPolicy Bypass -File .\INSTALAR.ps1
#   powershell -ExecutionPolicy Bypass -File .\INSTALAR.ps1 -OpenWeatherKey "SUA_CHAVE"     # opcional
param(
  [string]$OpenWeatherKey = '',
  [string]$InfluxUser     = 'bueiros',
  [string]$InfluxPassword = 'bueiros-senha-123',
  [string]$InfluxToken    = 'token-bueiros-mackenzie-troque-isto'
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$repo = Split-Path $root -Parent
$rt   = Join-Path $root 'runtime'
New-Item -ItemType Directory -Force $rt, "$rt\logs", "$rt\downloads" | Out-Null

function Passo($t) { Write-Host "`n==> $t" -ForegroundColor Cyan }
function Baixar($url, $dest) { if (-not (Test-Path $dest)) { Write-Host "    baixando $url"; Invoke-WebRequest $url -OutFile $dest -UseBasicParsing } else { Write-Host "    ja baixado: $dest" } }

Passo '1/7  Verificando o Node.js'
try { $v = (& node -v).TrimStart('v'); $maj = [int]($v.Split('.')[0]) } catch { throw 'Node.js nao encontrado. Instale o Node.js LTS em https://nodejs.org e rode de novo.' }
if ($maj -lt 18) { throw "Node.js $v e antigo demais. Instale a versao LTS (18 ou mais nova)." }
Write-Host "    Node.js $v ok"

Passo '2/7  Broker MQTT (Aedes) e pagina Monitor MQTT'
Push-Location "$root\broker"; npm install --no-fund --no-audit; Pop-Location

Passo '3/7  Node-RED + no do InfluxDB'
New-Item -ItemType Directory -Force "$rt\node-red", "$rt\node-red-data" | Out-Null
if (-not (Test-Path "$rt\node-red\package.json")) { Set-Content "$rt\node-red\package.json" '{"name":"bueiros-nodered","version":"1.0.0","private":true}' }
Push-Location "$rt\node-red"; npm install --no-fund --no-audit node-red@5.0.10 node-red-contrib-influxdb@0.7.0; Pop-Location

Passo '4/7  Baixando InfluxDB 2.7, influx CLI e Grafana 11.3'
Baixar 'https://download.influxdata.com/influxdb/releases/influxdb2-2.7.10-windows.zip' "$rt\downloads\influxdb2.zip"
Baixar 'https://download.influxdata.com/influxdb/releases/influxdb2-client-2.7.5-windows-amd64.zip' "$rt\downloads\influx-cli.zip"
Baixar 'https://dl.grafana.com/oss/release/grafana-11.3.1.windows-amd64.zip' "$rt\downloads\grafana.zip"
if (-not (Get-ChildItem "$rt\influxdb" -Recurse -Filter influxd.exe -ErrorAction SilentlyContinue))     { Expand-Archive "$rt\downloads\influxdb2.zip"  "$rt\influxdb"   -Force }
if (-not (Get-ChildItem "$rt\influx-cli" -Recurse -Filter influx.exe -ErrorAction SilentlyContinue))   { Expand-Archive "$rt\downloads\influx-cli.zip" "$rt\influx-cli" -Force }
if (-not (Get-ChildItem "$rt\grafana" -Recurse -Filter grafana-server.exe -ErrorAction SilentlyContinue)) { Expand-Archive "$rt\downloads\grafana.zip"    "$rt\grafana"    -Force }
$influxd = (Get-ChildItem "$rt\influxdb" -Recurse -Filter influxd.exe | Select-Object -First 1).FullName
$influx  = (Get-ChildItem "$rt\influx-cli" -Recurse -Filter influx.exe | Select-Object -First 1).FullName

Passo '5/7  Configurando o InfluxDB (usuario, organizacao, bucket e token)'
$ja = $false
try { $ja = (Test-NetConnection 127.0.0.1 -Port 8086 -WarningAction SilentlyContinue).TcpTestSucceeded } catch {}
if (-not $ja) {
  Start-Process $influxd -ArgumentList '--bolt-path', "`"$rt\influxdb-data\influxd.bolt`"", '--engine-path', "`"$rt\influxdb-data\engine`"", '--http-bind-address', '127.0.0.1:8086' -WindowStyle Hidden -RedirectStandardOutput "$rt\logs\influxd.out.log" -RedirectStandardError "$rt\logs\influxd.err.log"
}
for ($i = 0; $i -lt 40; $i++) { try { Invoke-RestMethod http://127.0.0.1:8086/health | Out-Null; break } catch { Start-Sleep -Seconds 2 } }
$setupOk = $true
$env:INFLUX_CONFIGS_PATH = "$rt\influx-configs"   # nao mexe em configuracoes do influx CLI ja existentes no PC
$ErrorActionPreference = 'Continue'
$saida = & $influx setup --host http://127.0.0.1:8086 --username $InfluxUser --password $InfluxPassword --org bueiros --bucket bueiros --token $InfluxToken --force 2>&1 | Out-String
$ErrorActionPreference = 'Stop'
if ($LASTEXITCODE -ne 0) {
  if ($saida -match 'already been set up|has already') { Write-Host '    (o InfluxDB ja estava configurado - mantendo a configuracao existente)' }
  else { throw "Falha ao configurar o InfluxDB: $saida (veja runtime\logs\influxd.err.log)" }
}

Passo '6/7  Configurando o Node-RED (fluxo, credenciais e variaveis)'
Copy-Item "$repo\docker\node-red\settings.js" "$rt\node-red-data\settings.js" -Force
Copy-Item "$repo\node-red\flows.json" "$rt\node-red-data\flows.json" -Force
$cred = @{ influx_cfg = @{ token = $InfluxToken } }
if ($OpenWeatherKey) { Set-Content "$rt\openweather.key" $OpenWeatherKey -Encoding ascii }
$cred | ConvertTo-Json -Depth 5 | Set-Content "$rt\node-red-data\flows_cred.json" -Encoding ascii

Passo '7/7  Configurando o Grafana (datasource e dashboard automaticos)'
$g = (Get-ChildItem "$rt\grafana" -Recurse -Filter grafana-server.exe | Select-Object -First 1).Directory.Parent.FullName
$prov = "$g\conf\provisioning"
New-Item -ItemType Directory -Force "$prov\datasources", "$prov\dashboards", "$rt\grafana-dashboards" | Out-Null
Copy-Item "$repo\grafana\bueiros-dashboard.json" "$rt\grafana-dashboards\bueiros.json" -Force
@"
apiVersion: 1
datasources:
  - name: InfluxDB-Bueiros
    uid: influx-bueiros
    type: influxdb
    access: proxy
    url: http://127.0.0.1:8086
    isDefault: true
    jsonData:
      version: Flux
      organization: bueiros
      defaultBucket: bueiros
      tlsSkipVerify: true
    secureJsonData:
      token: $InfluxToken
"@ | Set-Content "$prov\datasources\bueiros.yaml" -Encoding ascii
@"
apiVersion: 1
providers:
  - name: bueiros
    orgId: 1
    type: file
    allowUiUpdates: true
    options:
      path: $($rt -replace '\\','/')/grafana-dashboards
"@ | Set-Content "$prov\dashboards\bueiros.yaml" -Encoding ascii

Write-Host "`nInstalacao concluida." -ForegroundColor Green
Write-Host 'Proximo passo:  powershell -ExecutionPolicy Bypass -File .\INICIAR.ps1'
Write-Host "Login do InfluxDB (http://localhost:8086): usuario '$InfluxUser' e a senha definida no inicio deste script."
