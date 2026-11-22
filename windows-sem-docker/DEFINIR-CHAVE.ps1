# Guarda a chave do OpenWeatherMap e reinicia o Node-RED para usa-la.
# Uso:  powershell -ExecutionPolicy Bypass -File .\DEFINIR-CHAVE.ps1 -Chave "SUA_CHAVE"
param([Parameter(Mandatory = $true)][string]$Chave)
$rt = Join-Path $PSScriptRoot 'runtime'
if (-not (Test-Path $rt)) { Write-Host 'Rode primeiro o INSTALAR.ps1.' -ForegroundColor Red; exit 1 }
Set-Content "$rt\openweather.key" $Chave -Encoding ascii
# encerra somente o Node-RED deste projeto e liga de novo
Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object { $_.CommandLine -like '*node-red*red.js*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Start-Sleep -Seconds 2
& "$PSScriptRoot\INICIAR.ps1"
Write-Host 'Chave salva. No Node-RED, clique no quadrado do no "A cada 10 min" para consultar agora.' -ForegroundColor Green
