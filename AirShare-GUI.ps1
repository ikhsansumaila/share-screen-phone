# AirShare – GUI receiver layar HP untuk Windows (iPhone via AirPlay/UxPlay, Android via scrcpy).
#   powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File .\AirShare-GUI.ps1
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$here    = $PSScriptRoot
$runner  = Join-Path $here "airshare.ps1"
$icon    = @((Join-Path $here "airshare.ico"), (Join-Path $here "assets\airshare.ico")) | Where-Object { Test-Path $_ } | Select-Object -First 1
$uxGui   = Join-Path $env:ProgramFiles "uxplay-windows\uxplay-windows.exe"
$uxArgs  = Join-Path $env:APPDATA "leapbtw\uxplay-windows\arguments.txt"
$cfgDir  = Join-Path $env:APPDATA "AirShare"
$cfgFile = Join-Path $cfgDir "settings.json"
$scLog   = Join-Path $env:TEMP "AirShare-scrcpy.log"

# scrcpy + adb: dibundel di {app}\scrcpy, atau installer\vendor\scrcpy saat development
$scDir  = @((Join-Path $here "scrcpy"), (Join-Path $here "installer\vendor\scrcpy")) | Where-Object { Test-Path (Join-Path $_ "scrcpy.exe") } | Select-Object -First 1
$scrcpy = if ($scDir) { Join-Path $scDir "scrcpy.exe" }
$adb    = if ($scDir) { Join-Path $scDir "adb.exe" }

# Satu jendela saja
$created = $false
$mutex = New-Object System.Threading.Mutex($true, "Local\AirShareGUI", [ref]$created)
if (-not $created) { [System.Windows.Forms.MessageBox]::Show("AirShare sudah terbuka.", "AirShare") | Out-Null; exit }

function New-Pin { "{0:D4}" -f (Get-Random -Minimum 0 -Maximum 10000) }
function Show-Msg($text, $icon = "Warning") { [System.Windows.Forms.MessageBox]::Show($text, "AirShare", "OK", $icon) | Out-Null }
function Test-IphoneRunning { [bool](Get-Process uxplay-windows, uxplay -ErrorAction SilentlyContinue) }
function Test-AndroidRunning { [bool](Get-Process scrcpy -ErrorAction SilentlyContinue) }

# Pengaturan tersimpan
$cfg = [ordered]@{
  Mode = "iphone"
  Name = "AirShare-$env:COMPUTERNAME"; UsePin = $true; Pin = (New-Pin); Res = "1920x1080@60"; Fullscreen = $true
  AWifi = $false; AIp = ""; AMaxSize = "0"; AFullscreen = $false; AScreenOff = $false
}
if (Test-Path $cfgFile) {
  try {
    $saved = Get-Content $cfgFile -Raw | ConvertFrom-Json
    foreach ($k in @($cfg.Keys)) { if ($null -ne $saved.$k) { $cfg[$k] = $saved.$k } }
  } catch {}
}
function Save-Config { New-Item -ItemType Directory -Force $cfgDir | Out-Null; $cfg | ConvertTo-Json | Set-Content $cfgFile -Encoding UTF8 }

# ---------- UI dasar ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = "AirShare"
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96)
$form.AutoScaleMode = "Dpi"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.StartPosition = "CenterScreen"
$form.ClientSize = New-Object System.Drawing.Size(440, 466)
if ($icon) { try { $form.Icon = New-Object System.Drawing.Icon($icon) } catch {} }

function Add-Ctl($parent, $ctl, $x, $y, $w, $h) {
  $ctl.Location = New-Object System.Drawing.Point($x, $y)
  $ctl.Size = New-Object System.Drawing.Size($w, $h)
  $parent.Controls.Add($ctl)
  $ctl
}
function New-Label($parent, $text, $x, $y, $w = 125) { $l = Add-Ctl $parent (New-Object System.Windows.Forms.Label) $x $y $w 22; $l.Text = $text; $l }

$lblTitle = Add-Ctl $form (New-Object System.Windows.Forms.Label) 20 14 400 32
$lblTitle.Text = "AirShare"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 16)
$lblSub = Add-Ctl $form (New-Object System.Windows.Forms.Label) 20 46 400 22
$lblSub.Text = "Mirror layar HP ke PC ini"
$lblSub.ForeColor = [System.Drawing.Color]::DimGray

# Pilihan jenis HP
$null = New-Label $form "Jenis HP" 20 83
$rbIphone = Add-Ctl $form (New-Object System.Windows.Forms.RadioButton) 150 80 100 26
$rbIphone.Text = "iPhone"
$rbAndroid = Add-Ctl $form (New-Object System.Windows.Forms.RadioButton) 260 80 120 26
$rbAndroid.Text = "Android"
if ($cfg.Mode -eq "android") { $rbAndroid.Checked = $true } else { $rbIphone.Checked = $true }

$pnlI = Add-Ctl $form (New-Object System.Windows.Forms.Panel) 0 114 440 352
$pnlA = Add-Ctl $form (New-Object System.Windows.Forms.Panel) 0 114 440 352
$pnlA.Visible = $rbAndroid.Checked
$pnlI.Visible = -not $rbAndroid.Checked

# ---------- Panel iPhone ----------
$null = New-Label $pnlI "Nama receiver" 20 11
$txtName = Add-Ctl $pnlI (New-Object System.Windows.Forms.TextBox) 150 8 270 26
$txtName.Text = $cfg.Name
$txtName.MaxLength = 40

$chkPin = Add-Ctl $pnlI (New-Object System.Windows.Forms.CheckBox) 20 44 125 26
$chkPin.Text = "Pakai PIN"
$chkPin.Checked = [bool]$cfg.UsePin
$txtPin = Add-Ctl $pnlI (New-Object System.Windows.Forms.TextBox) 150 44 80 26
$txtPin.Text = $cfg.Pin
$txtPin.MaxLength = 4
$btnPin = Add-Ctl $pnlI (New-Object System.Windows.Forms.Button) 240 43 80 28
$btnPin.Text = "Acak"

$null = New-Label $pnlI "Resolusi" 20 83
$cmbRes = Add-Ctl $pnlI (New-Object System.Windows.Forms.ComboBox) 150 80 270 26
$cmbRes.DropDownStyle = "DropDownList"
$resList = @("1920x1080@60", "1280x720@60", "2560x1440@60", "3840x2160@30")
if ($resList -notcontains $cfg.Res) { $resList += $cfg.Res }
$cmbRes.Items.AddRange($resList)
$cmbRes.SelectedItem = $cfg.Res

$chkFs = Add-Ctl $pnlI (New-Object System.Windows.Forms.CheckBox) 20 116 400 26
$chkFs.Text = "Layar penuh (fullscreen) saat mirroring"
$chkFs.Checked = [bool]$cfg.Fullscreen

$btnStartI = Add-Ctl $pnlI (New-Object System.Windows.Forms.Button) 20 158 195 42
$btnStartI.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
$btnStopI = Add-Ctl $pnlI (New-Object System.Windows.Forms.Button) 225 158 195 42
$btnStopI.Text = "Hentikan"

$lblStatusI = Add-Ctl $pnlI (New-Object System.Windows.Forms.Label) 20 216 400 24
$lblStatusI.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 11)
$lblHintI = Add-Ctl $pnlI (New-Object System.Windows.Forms.Label) 20 244 400 62
$lblNet = Add-Ctl $pnlI (New-Object System.Windows.Forms.Label) 20 306 400 44
$lblNet.ForeColor = [System.Drawing.Color]::DarkOrange

# ---------- Panel Android ----------
$null = New-Label $pnlA "Koneksi" 20 11
$rbUsb = Add-Ctl $pnlA (New-Object System.Windows.Forms.RadioButton) 150 8 110 26
$rbUsb.Text = "Kabel USB"
$rbWifi = Add-Ctl $pnlA (New-Object System.Windows.Forms.RadioButton) 270 8 110 26
$rbWifi.Text = "Wi-Fi"
$rbWifi.Checked = [bool]$cfg.AWifi
$rbUsb.Checked = -not $rbWifi.Checked

$null = New-Label $pnlA "IP HP" 20 47
$txtIp = Add-Ctl $pnlA (New-Object System.Windows.Forms.TextBox) 150 44 140 26
$txtIp.Text = $cfg.AIp
$btnWifi = Add-Ctl $pnlA (New-Object System.Windows.Forms.Button) 300 43 120 28
$btnWifi.Text = "Siapkan Wi-Fi"

$null = New-Label $pnlA "Resolusi maks" 20 83
$cmbMax = Add-Ctl $pnlA (New-Object System.Windows.Forms.ComboBox) 150 80 270 26
$cmbMax.DropDownStyle = "DropDownList"
$maxCodes = @("0", "1920", "1600", "1280", "1024")
$cmbMax.Items.AddRange(@("Asli (kualitas terbaik)", "1920 px", "1600 px", "1280 px (lebih ringan)", "1024 px (paling ringan)"))
$cmbMax.SelectedIndex = [Math]::Max(0, [array]::IndexOf($maxCodes, [string]$cfg.AMaxSize))

$chkFsA = Add-Ctl $pnlA (New-Object System.Windows.Forms.CheckBox) 20 116 180 26
$chkFsA.Text = "Layar penuh"
$chkFsA.Checked = [bool]$cfg.AFullscreen
$chkOff = Add-Ctl $pnlA (New-Object System.Windows.Forms.CheckBox) 210 116 210 26
$chkOff.Text = "Matikan layar HP"
$chkOff.Checked = [bool]$cfg.AScreenOff

$btnStartA = Add-Ctl $pnlA (New-Object System.Windows.Forms.Button) 20 158 195 42
$btnStartA.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
$btnStopA = Add-Ctl $pnlA (New-Object System.Windows.Forms.Button) 225 158 195 42
$btnStopA.Text = "Hentikan"

$lblStatusA = Add-Ctl $pnlA (New-Object System.Windows.Forms.Label) 20 216 400 24
$lblStatusA.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 11)
$lblHintA = Add-Ctl $pnlA (New-Object System.Windows.Forms.Label) 20 244 400 78
$lnkHelp = Add-Ctl $pnlA (New-Object System.Windows.Forms.LinkLabel) 20 324 400 24
$lnkHelp.Text = "Cara mengaktifkan USB debugging di HP"

# ---------- Logika iPhone ----------
function Update-IphoneStatus {
  if (Test-IphoneRunning) {
    $lblStatusI.Text = "● Aktif"
    $lblStatusI.ForeColor = [System.Drawing.Color]::SeaGreen
    $btnStartI.Text = "Terapkan ulang"
    $btnStopI.Enabled = $true
    # Nama/PIN yang benar-benar dipakai UxPlay saat ini
    $name = $cfg.Name; $pin = $null
    try {
      $t = @((Get-Content $uxArgs -Raw -ErrorAction Stop).Trim() -split '\s+')
      $i = [array]::IndexOf($t, "-n");   if ($i -ge 0 -and $i + 1 -lt $t.Count) { $name = $t[$i + 1] }
      $i = [array]::IndexOf($t, "-pin"); if ($i -ge 0 -and $i + 1 -lt $t.Count) { $pin = $t[$i + 1] }
    } catch { if ($cfg.UsePin) { $pin = $cfg.Pin } }
    $hint = "Di iPhone: sambung ke Wi-Fi yang sama → Control Center → Screen Mirroring → pilih `"$name`"."
    if ($pin) { $hint += "`nPIN: $pin" }
    $lblHintI.Text = $hint
  } else {
    $lblStatusI.Text = "● Tidak aktif"
    $lblStatusI.ForeColor = [System.Drawing.Color]::Gray
    $btnStartI.Text = "Mulai"
    $btnStopI.Enabled = $false
    $lblHintI.Text = "Tekan Mulai untuk menyalakan receiver.`nMenutup jendela ini juga menghentikan receiver."
  }
}

function Update-Network {
  $warn = ""
  try {
    $profiles = @(Get-NetConnectionProfile -ErrorAction Stop)
    $rule = Get-NetFirewallRule -DisplayName "AirShare TCP" -ErrorAction SilentlyContinue
    $pub = @($profiles | Where-Object { "$($_.NetworkCategory)" -eq "Public" })
    if ($profiles.Count -eq 0) {
      $warn = "PC tidak terhubung ke jaringan."
    } elseif (-not $rule) {
      $warn = "Aturan firewall AirShare belum ada. Jalankan ulang installer AirShare."
    } elseif ($pub.Count -gt 0 -and "$($rule.Profile)" -notmatch "Public|Any") {
      $warn = "Jaringan `"$($pub[0].Name)`" berstatus Public, firewall belum mengizinkannya. Ubah jaringan ke Private, atau install ulang dengan opsi Wi-Fi Public."
    }
  } catch {}
  $lblNet.Text = $warn
}

$chkPin.Add_CheckedChanged({ $txtPin.Enabled = $chkPin.Checked; $btnPin.Enabled = $chkPin.Checked })
$btnPin.Add_Click({ $txtPin.Text = New-Pin })
$txtPin.Add_KeyPress({ if (-not [char]::IsDigit($_.KeyChar) -and -not [char]::IsControl($_.KeyChar)) { $_.Handled = $true } })

$btnStartI.Add_Click({
  $name = $txtName.Text.Trim() -replace '\s+', '-'
  if ($name -notmatch '^[A-Za-z0-9._-]{1,40}$') { Show-Msg "Nama hanya boleh huruf, angka, titik, - dan _ (tanpa spasi)."; return }
  if ($chkPin.Checked -and $txtPin.Text -notmatch '^\d{4}$') { Show-Msg "PIN harus 4 angka."; return }
  if (-not (Test-Path $uxGui)) { Show-Msg "UxPlay belum terpasang. Jalankan ulang installer AirShare."; return }

  $txtName.Text = $name
  $cfg.Name = $name; $cfg.UsePin = $chkPin.Checked; $cfg.Pin = $txtPin.Text
  $cfg.Res = [string]$cmbRes.SelectedItem; $cfg.Fullscreen = $chkFs.Checked
  Save-Config

  $p = @{ Name = $name; Res = $cfg.Res }
  if ($chkPin.Checked) { $p.Pin = $txtPin.Text }
  if (-not $chkFs.Checked) { $p.Windowed = $true }

  $form.UseWaitCursor = $true
  & $runner @p | Out-Null
  Start-Sleep -Milliseconds 800
  $form.UseWaitCursor = $false
  Update-IphoneStatus
  Update-Network
})

$btnStopI.Add_Click({ & $runner -Stop | Out-Null; Start-Sleep -Milliseconds 300; Update-IphoneStatus })

# ---------- Logika Android ----------
function Invoke-Adb([string[]]$A) {
  if (-not $adb) { return @() }
  @(& $adb @A 2>&1 | ForEach-Object { "$_" })
}

function Get-AndroidDevices {
  Invoke-Adb @("devices", "-l") | Select-Object -Skip 1 | Where-Object { $_ -match '^\S+\s+\S+' -and $_ -notmatch '^\*' } | ForEach-Object {
    $parts = $_ -split '\s+'
    $model = if ($_ -match 'model:(\S+)') { $Matches[1] -replace '_', ' ' } else { $parts[0] }
    [pscustomobject]@{ Serial = $parts[0]; State = $parts[1]; Model = $model; Wifi = ($parts[0] -match ':\d+$') }
  }
}

function Update-AndroidControls {
  $txtIp.Enabled = $rbWifi.Checked
  $btnWifi.Enabled = $rbWifi.Checked
}

function Update-AndroidStatus {
  if (-not $scrcpy) {
    $lblStatusA.Text = "● scrcpy tidak ditemukan"
    $lblStatusA.ForeColor = [System.Drawing.Color]::DarkOrange
    $lblHintA.Text = "Komponen Android tidak ikut terpasang. Jalankan ulang installer AirShare."
    $btnStartA.Enabled = $false; $btnStopA.Enabled = $false
    return
  }
  if (Test-AndroidRunning) {
    $lblStatusA.Text = "● Aktif"
    $lblStatusA.ForeColor = [System.Drawing.Color]::SeaGreen
    $lblHintA.Text = "Layar HP tampil di jendela `"AirShare-Android`". HP bisa dikontrol dengan mouse dan keyboard PC.`nTutup jendela itu atau tekan Hentikan untuk berhenti."
    $btnStartA.Text = "Mulai ulang"
    $btnStopA.Enabled = $true
    return
  }
  $btnStartA.Text = "Mulai"
  $btnStartA.Enabled = $true
  $btnStopA.Enabled = $false
  $devs = @(Get-AndroidDevices)
  $ready = @($devs | Where-Object State -eq "device")
  if ($ready.Count -gt 0) {
    $d = $ready[0]
    $lblStatusA.Text = "● Siap: $($d.Model) (" + $(if ($d.Wifi) { "Wi-Fi" } else { "USB" }) + ")"
    $lblStatusA.ForeColor = [System.Drawing.Color]::SeaGreen
    $lblHintA.Text = "Tekan Mulai untuk menampilkan layar HP."
  } elseif (@($devs | Where-Object State -eq "unauthorized").Count -gt 0) {
    $lblStatusA.Text = "● Menunggu izin di HP"
    $lblStatusA.ForeColor = [System.Drawing.Color]::DarkOrange
    $lblHintA.Text = "Buka layar HP, lalu pada popup `"Allow USB debugging?`" centang `"Always allow`" dan tekan Allow."
  } else {
    $lblStatusA.Text = "● Belum ada HP terhubung"
    $lblStatusA.ForeColor = [System.Drawing.Color]::Gray
    if ($rbWifi.Checked -and $txtIp.Text) {
      $lblHintA.Text = "Mode Wi-Fi: tekan Mulai untuk menyambung ke $($txtIp.Text). Kalau gagal (misalnya HP baru restart), colok USB sekali lalu tekan Siapkan Wi-Fi."
    } else {
      $lblHintA.Text = "Colok HP ke PC dengan kabel USB (USB debugging harus aktif). Untuk tanpa kabel: pilih Wi-Fi, colok USB sekali, lalu tekan Siapkan Wi-Fi."
    }
  }
}

function Save-AndroidConfig {
  $cfg.AWifi = $rbWifi.Checked; $cfg.AIp = $txtIp.Text.Trim()
  $cfg.AMaxSize = $maxCodes[$cmbMax.SelectedIndex]
  $cfg.AFullscreen = $chkFsA.Checked; $cfg.AScreenOff = $chkOff.Checked
  Save-Config
}

function Stop-Android {
  $procs = @(Get-Process scrcpy -ErrorAction SilentlyContinue)
  foreach ($p in $procs) { $null = $p.CloseMainWindow() }   # tutup normal supaya layar HP kembali menyala
  foreach ($p in $procs) { if (-not $p.WaitForExit(2000)) { try { $p.Kill() } catch {} } }
}

$rbUsb.Add_CheckedChanged({ Update-AndroidControls })
$rbWifi.Add_CheckedChanged({ Update-AndroidControls })

$btnWifi.Add_Click({
  $usb = @(Get-AndroidDevices | Where-Object { $_.State -eq "device" -and -not $_.Wifi }) | Select-Object -First 1
  if (-not $usb) { Show-Msg "Colok HP lewat kabel USB dulu (USB debugging aktif dan sudah diizinkan), lalu coba lagi."; return }
  $form.UseWaitCursor = $true
  $ip = $null
  foreach ($line in (Invoke-Adb @("-s", $usb.Serial, "shell", "ip", "route"))) {
    if ($line -match 'wlan\S*.*\bsrc (\d+\.\d+\.\d+\.\d+)') { $ip = $Matches[1]; break }
  }
  if (-not $ip) { $form.UseWaitCursor = $false; Show-Msg "IP Wi-Fi HP tidak ditemukan. Pastikan HP tersambung ke Wi-Fi yang sama dengan PC."; return }
  $null = Invoke-Adb @("-s", $usb.Serial, "tcpip", "5555")
  Start-Sleep -Seconds 2
  $out = (Invoke-Adb @("connect", "${ip}:5555")) -join " "
  $form.UseWaitCursor = $false
  if ($out -match "connected to") {
    $txtIp.Text = $ip
    Save-AndroidConfig
    Show-Msg "Wi-Fi siap ($ip). Kabel USB boleh dicabut.`nCatatan: setelah HP restart, langkah ini perlu diulang." "Information"
  } else {
    Show-Msg "Gagal menyambung ke ${ip}:5555.`n$out"
  }
  Update-AndroidStatus
})

$btnStartA.Add_Click({
  Save-AndroidConfig
  Stop-Android

  $a = @("--window-title=AirShare-Android", "--stay-awake")
  if ($cfg.AMaxSize -ne "0") { $a += "--max-size=$($cfg.AMaxSize)" }
  if ($cfg.AFullscreen) { $a += "--fullscreen" }
  if ($cfg.AScreenOff) { $a += "--turn-screen-off" }

  $form.UseWaitCursor = $true
  if ($rbWifi.Checked) {
    $ip = $txtIp.Text.Trim()
    if ($ip -notmatch '^\d+\.\d+\.\d+\.\d+(:\d+)?$') { $form.UseWaitCursor = $false; Show-Msg "Isi IP HP dulu, atau tekan Siapkan Wi-Fi (dengan HP tercolok USB)."; return }
    if ($ip -notmatch ':') { $ip = "${ip}:5555" }
    $out = (Invoke-Adb @("connect", $ip)) -join " "
    if ($out -notmatch "connected to") { $form.UseWaitCursor = $false; Show-Msg "Tidak bisa menyambung ke $ip.`nColok USB sekali lalu tekan Siapkan Wi-Fi.`n`n$out"; return }
    $a += "--serial=$ip"
  } else {
    if (-not @(Get-AndroidDevices | Where-Object { $_.State -eq "device" -and -not $_.Wifi })) { $form.UseWaitCursor = $false; Show-Msg "HP belum terdeteksi lewat USB. Lihat petunjuk di bawah tombol."; return }
    $a += "--select-usb"
  }

  # Jalankan tanpa jendela konsol; output dicatat ke log
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $env:ComSpec
  $psi.Arguments = "/s /c `"`"$scrcpy`" $($a -join ' ') > `"$scLog`" 2>&1`""
  $psi.WorkingDirectory = $scDir
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $null = [System.Diagnostics.Process]::Start($psi)

  Start-Sleep -Seconds 3
  $form.UseWaitCursor = $false
  if (-not (Test-AndroidRunning)) {
    $tail = if (Test-Path $scLog) { (Get-Content $scLog -Tail 6) -join "`n" } else { "" }
    Show-Msg "scrcpy berhenti / gagal dijalankan.`n`n$tail"
  }
  Update-AndroidStatus
})

$btnStopA.Add_Click({ Stop-Android; Update-AndroidStatus })

$lnkHelp.Add_LinkClicked({
  Show-Msg (@(
    "1. Di HP buka Settings → About phone (Tentang ponsel).",
    "2. Ketuk 'Build number' (Nomor bentukan) 7 kali sampai muncul 'You are now a developer'.",
    "   Xiaomi: ketuk 'MIUI/HyperOS version'. Samsung: Software information → Build number.",
    "3. Kembali ke Settings → System → Developer options, nyalakan 'USB debugging'.",
    "   Xiaomi: nyalakan juga 'USB debugging (Security settings)' agar bisa dikontrol dari PC.",
    "4. Colok HP ke PC, pada popup 'Allow USB debugging?' centang 'Always allow' lalu Allow.",
    "",
    "Kalau HP tetap tidak terdeteksi: ganti kabel (pakai kabel data, bukan kabel charge saja)",
    "dan pasang driver USB dari pabrikan HP (misalnya Samsung USB Driver)."
  ) -join "`n") "Information"
})

# ---------- Mode & timer ----------
function Set-Mode {
  $isA = $rbAndroid.Checked
  $pnlA.Visible = $isA
  $pnlI.Visible = -not $isA
  $cfg.Mode = if ($isA) { "android" } else { "iphone" }
  if ($isA) { Update-AndroidControls; Update-AndroidStatus } else { Update-IphoneStatus; Update-Network }
}
$rbIphone.Add_CheckedChanged({ if ($rbIphone.Checked) { Set-Mode; Save-Config } })
$rbAndroid.Add_CheckedChanged({ if ($rbAndroid.Checked) { Set-Mode; Save-Config } })

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 2000
$timer.Add_Tick({ if ($pnlA.Visible) { Update-AndroidStatus } else { Update-IphoneStatus } })

$form.Add_Shown({
  $txtPin.Enabled = $chkPin.Checked; $btnPin.Enabled = $chkPin.Checked
  Set-Mode
  $timer.Start()
})
$form.Add_FormClosing({
  $timer.Stop()
  if (Test-IphoneRunning) { & $runner -Stop | Out-Null }
  if (Test-AndroidRunning) { Stop-Android }
  if ($adb) { $null = Invoke-Adb @("kill-server") }   # lepas kunci file adb.exe (penting saat update/uninstall)
})

[System.Windows.Forms.Application]::Run($form)
$mutex.ReleaseMutex()
