# AirShare – mirror layar HP ke monitor Windows/Ubuntu

- **iPhone**: Screen Mirroring (AirPlay) bawaan iPhone + UxPlay sebagai receiver (Wi-Fi).
- **Android** (Windows, lewat GUI): scrcpy – kabel USB atau Wi-Fi, butuh USB debugging aktif.

## Ubuntu
    ./install-ubuntu.sh      # sekali saja
    ./airshare.sh            # NAME=RuangRapat PIN=1234 FULLSCREEN=0 ./airshare.sh

## Windows – installer + GUI
Jalankan `dist\AirShare-Setup-<versi>.exe` (perlu internet untuk mengunduh UxPlay). Setelah itu buka **AirShare** dari Start Menu/Desktop, pilih **iPhone** atau **Android**, lalu klik **Mulai**.
Opsi "Izinkan juga di Wi-Fi berstatus Public" ada di halaman Tasks installer.

Android:
1. Di HP: Settings → About phone → ketuk *Build number* 7x → Developer options → nyalakan **USB debugging**.
2. Colok USB, izinkan popup *Allow USB debugging*, klik **Mulai**.
3. Tanpa kabel: pilih **Wi-Fi**, colok USB sekali, klik **Siapkan Wi-Fi**, lalu cabut kabel. Ulangi setelah HP restart.

Build installer (butuh Inno Setup – dipasang otomatis lewat winget; scrcpy diunduh dari GitHub dan diverifikasi SHA-256):

    .\build-installer.ps1 -Version 1.1.0

## Windows – lewat script (PowerShell Administrator)
    powershell -ExecutionPolicy Bypass -File .\install-windows.ps1           # Wi-Fi Private
    powershell -ExecutionPolicy Bypass -File .\install-windows.ps1 -Public   # Wi-Fi tetap Public
    .\airshare.ps1 -Name RuangRapat -Pin 1234   # tambah -Windowed untuk mode jendela
    .\airshare.ps1 -Stop                        # receiver jalan di system tray

## Di iPhone
Satu Wi-Fi dengan PC -> Control Center -> Screen Mirroring -> pilih nama receiver.

## Masalah umum
- Tidak muncul di daftar: pastikan Wi-Fi sama (bukan guest/AP isolation), firewall terbuka, avahi/Bonjour jalan.
- Wayland: jika layar hitam, coba `./airshare.sh -vs waylandsink` atau login sesi X11.
- Lambat di PC lama: `./airshare.sh -avdec`.
- Netflix/Disney+/Prime Video: video hitam saat mirroring karena DRM aplikasinya – tidak bisa diatasi dari receiver.
- Android tidak terdeteksi: pakai kabel data (bukan kabel charge saja), pasang driver USB pabrikan HP; Xiaomi perlu juga *USB debugging (Security settings)*. Log scrcpy: `%TEMP%\AirShare-scrcpy.log`.
