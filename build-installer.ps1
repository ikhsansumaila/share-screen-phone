# Build installer Windows: dist\AirShare-Setup-<versi>.exe
#   .\build-installer.ps1 -Version 1.1.0
param([string]$Version = "1.1.0")
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

# scrcpy (Android) yang dibundel – versi dipin + diverifikasi SHA-256
$ScrcpyVersion = "v5.0.1"
$ScrcpySha256  = "b12a2c4ee8be317422451fc7dcf8ee20a71b5ea7ef9ad73ddd825a25316227a5"

if (-not (Test-Path "$root\assets\airshare.ico")) { & "$root\installer\make-icon.ps1" }

# 1) Siapkan installer\vendor\scrcpy
$vendor = "$root\installer\vendor"
$scDir  = "$vendor\scrcpy"
$stamp  = "$scDir\.version"
if (-not (Test-Path $stamp) -or (Get-Content $stamp -Raw).Trim() -ne $ScrcpyVersion) {
  Write-Host "Mengunduh scrcpy $ScrcpyVersion..."
  New-Item -ItemType Directory -Force $vendor | Out-Null
  $zip = "$vendor\scrcpy-win64-$ScrcpyVersion.zip"
  if (-not (Test-Path $zip)) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest "https://github.com/Genymobile/scrcpy/releases/download/$ScrcpyVersion/scrcpy-win64-$ScrcpyVersion.zip" -OutFile $zip -UseBasicParsing
  }
  $hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
  if ($hash -ne $ScrcpySha256) { Remove-Item $zip -Force; throw "Hash scrcpy tidak cocok ($hash). Unduhan dibatalkan." }

  $tmp = "$vendor\_extract"
  Remove-Item $tmp, $scDir -Recurse -Force -ErrorAction SilentlyContinue
  Expand-Archive $zip $tmp
  $inner = Get-ChildItem $tmp -Recurse -Filter scrcpy.exe | Select-Object -First 1
  if (-not $inner) { throw "scrcpy.exe tidak ada di dalam zip." }
  Move-Item $inner.DirectoryName $scDir
  Remove-Item $tmp -Recurse -Force
  Set-Content $stamp $ScrcpyVersion -Encoding ascii
}

# 2) Inno Setup
function Find-Iscc {
  $c = Get-Command iscc -ErrorAction SilentlyContinue
  if ($c) { return $c.Source }
  Get-ChildItem "${env:ProgramFiles(x86)}\Inno Setup*\ISCC.exe", "$env:ProgramFiles\Inno Setup*\ISCC.exe", "$env:LOCALAPPDATA\Programs\Inno Setup*\ISCC.exe" -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty FullName
}

$iscc = Find-Iscc
if (-not $iscc) {
  Write-Host "Inno Setup belum ada, memasang lewat winget..."
  winget install --id JRSoftware.InnoSetup -e --accept-source-agreements --accept-package-agreements
  $iscc = Find-Iscc
  if (-not $iscc) { throw "ISCC.exe tidak ditemukan setelah instalasi Inno Setup." }
}

# 3) Compile
& $iscc "/DAppVersion=$Version" "$root\installer\AirShare.iss"
if ($LASTEXITCODE -ne 0) { throw "Build gagal (ISCC exit $LASTEXITCODE)." }
Write-Host "Installer: $root\dist\AirShare-Setup-$Version.exe"
