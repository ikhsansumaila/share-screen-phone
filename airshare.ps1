# Jalankan receiver AirPlay di Windows.
#   .\airshare.ps1 -Name RuangRapat -Pin 1234
#   .\airshare.ps1 -Stop
param([string]$Name = "AirShare-$env:COMPUTERNAME", [string]$Pin = "", [string]$Res = "1920x1080@60", [switch]$Windowed, [switch]$Stop)

$a = @("-n", $Name, "-nh", "-p", "-s", $Res, "-vsync", "no")
if (-not $Windowed) { $a += @("-vs", "d3d11videosink", "-fs") }
if ($Pin) { $a += @("-pin", $Pin) }
function Stop-UxPlay { Get-Process uxplay-windows, uxplay-bluetooth-beacon, uxplay -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }

if ($Stop) { Stop-UxPlay; Write-Host "Receiver dihentikan."; exit 0 }

# 1) Build CLI klasik (uxplay.exe) kalau ada
$exe = (Get-Command uxplay -ErrorAction SilentlyContinue).Source
if ($exe) {
  Write-Host "Receiver aktif dengan nama: $Name (Ctrl+C untuk berhenti)"
  & $exe @a
  exit $LASTEXITCODE
}

# 2) uxplay-windows (aplikasi tray, winget leapbtw.uxplay): argumen dibaca dari arguments.txt
$gui = @("$env:ProgramFiles\uxplay-windows\uxplay-windows.exe", "$env:LOCALAPPDATA\Programs\uxplay-windows\uxplay-windows.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $gui) { Write-Host "UxPlay tidak ditemukan. Jalankan .\install-windows.ps1 (sebagai Administrator)"; exit 1 }

$cfgDir = Join-Path $env:APPDATA "leapbtw\uxplay-windows"
New-Item -ItemType Directory -Force $cfgDir | Out-Null
[IO.File]::WriteAllText((Join-Path $cfgDir "arguments.txt"), ($a -join " "))

Stop-UxPlay
Start-Sleep -Milliseconds 500
Start-Process $gui | Out-Null
Write-Host "Receiver aktif dengan nama: $Name (berjalan di system tray)."
Write-Host "Hentikan dengan: .\airshare.ps1 -Stop"
