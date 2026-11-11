# Pasang receiver AirPlay di Windows 10/11. Jalankan PowerShell sebagai Administrator:
#   powershell -ExecutionPolicy Bypass -File .\install-windows.ps1           # Wi-Fi Private
#   powershell -ExecutionPolicy Bypass -File .\install-windows.ps1 -Public   # Wi-Fi tetap Public
# (Installer AirShare-Setup.exe menjalankan script ini otomatis.)
param([switch]$Public)
$ErrorActionPreference = "Stop"
$fwProfile = if ($Public) { "Private,Public" } else { "Private" }
try { Start-Transcript -Path (Join-Path $env:TEMP "AirShare-install.log") -Append | Out-Null } catch {}

$winget = Get-Command winget -ErrorAction SilentlyContinue
if (-not $winget) { Write-Host "winget tidak ditemukan. Pasang 'App Installer' dari Microsoft Store." }

# 1) Bonjour (dibutuhkan untuk discovery; sudah ada kalau iTunes/iCloud terpasang)
if (-not (Get-Service -Name "Bonjour Service" -ErrorAction SilentlyContinue) -and $winget) {
  Write-Host "Memasang Bonjour..."
  winget install --id Apple.Bonjour -e --silent --accept-source-agreements --accept-package-agreements
}

# 2) UxPlay untuk Windows (build komunitas, aplikasi tray)
$app = "$env:ProgramFiles\uxplay-windows\uxplay-windows.exe"
if (Test-Path $app) {
  Write-Host "UxPlay sudah terpasang."
} elseif ($winget) {
  Write-Host "Memasang UxPlay untuk Windows..."
  winget install --id leapbtw.uxplay -e --silent --accept-source-agreements --accept-package-agreements
}
if (-not (Test-Path $app)) {
  Write-Host "UxPlay gagal dipasang. Unduh installer manual dari: https://github.com/leapbtw/uxplay-windows/releases"
}

# 3) Firewall
Remove-NetFirewallRule -DisplayName "AirShare*" -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "AirShare TCP" -Direction Inbound -Protocol TCP -LocalPort 7000-7100 -Action Allow -Profile $fwProfile -ErrorAction SilentlyContinue | Out-Null
New-NetFirewallRule -DisplayName "AirShare UDP" -Direction Inbound -Protocol UDP -LocalPort 6000-7011,5353 -Action Allow -Profile $fwProfile -ErrorAction SilentlyContinue | Out-Null
if (Test-Path $app) { New-NetFirewallRule -DisplayName "AirShare App" -Direction Inbound -Program $app -Action Allow -Profile $fwProfile -ErrorAction SilentlyContinue | Out-Null }

Write-Host "Selesai. Jalankan: .\airshare.ps1 atau AirShare dari Start Menu"
try { Stop-Transcript | Out-Null } catch {}
if (-not (Test-Path $app)) { exit 1 }
