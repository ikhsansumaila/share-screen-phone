; Inno Setup script untuk AirShare (Windows). Build: .\build-installer.ps1
#ifndef AppVersion
  #define AppVersion "1.1.0"
#endif
#define PS "{sys}\WindowsPowerShell\v1.0\powershell.exe"
#define GuiArgs '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ""{app}\AirShare-GUI.ps1""'

[Setup]
AppId={{6B1E2F4A-3C7D-4E8B-9A10-2F5D7C3E9B41}
AppName=AirShare
AppVersion={#AppVersion}
AppVerName=AirShare {#AppVersion}
AppPublisher=AirShare
DefaultDirName={autopf}\AirShare
DefaultGroupName=AirShare
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir=..\dist
OutputBaseFilename=AirShare-Setup-{#AppVersion}
SetupIconFile=..\assets\airshare.ico
UninstallDisplayIcon={app}\airshare.ico
UninstallDisplayName=AirShare
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes

[Languages]
#if FileExists(AddBackslash(CompilerPath) + "Languages\Indonesian.isl")
Name: "id"; MessagesFile: "compiler:Languages\Indonesian.isl"
#endif
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Buat shortcut di Desktop"; GroupDescription: "Shortcut:"
Name: "publicwifi"; Description: "Izinkan juga di Wi-Fi berstatus Public (kurang aman)"; GroupDescription: "Firewall:"; Flags: unchecked

[Files]
Source: "..\AirShare-GUI.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\airshare.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\install-windows.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\assets\airshare.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
; Android: scrcpy + adb (diunduh oleh build-installer.ps1)
Source: "vendor\scrcpy\*"; DestDir: "{app}\scrcpy"; Excludes: ".version"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\AirShare"; Filename: "{#PS}"; Parameters: "{#GuiArgs}"; WorkingDir: "{app}"; IconFilename: "{app}\airshare.ico"; Comment: "Mirror layar HP (iPhone/Android) ke PC ini"
Name: "{autodesktop}\AirShare"; Filename: "{#PS}"; Parameters: "{#GuiArgs}"; WorkingDir: "{app}"; IconFilename: "{app}\airshare.ico"; Comment: "Mirror layar HP (iPhone/Android) ke PC ini"; Tasks: desktopicon

[Run]
Filename: "{#PS}"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\install-windows.ps1"""; StatusMsg: "Memasang UxPlay, Bonjour dan aturan firewall (butuh internet, bisa beberapa menit)..."; Flags: runhidden waituntilterminated; Tasks: not publicwifi
Filename: "{#PS}"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\install-windows.ps1"" -Public"; StatusMsg: "Memasang UxPlay, Bonjour dan aturan firewall (butuh internet, bisa beberapa menit)..."; Flags: runhidden waituntilterminated; Tasks: publicwifi
Filename: "{#PS}"; Parameters: "{#GuiArgs}"; Description: "Jalankan AirShare sekarang"; Flags: postinstall nowait skipifsilent runasoriginaluser

[UninstallRun]
Filename: "{#PS}"; Parameters: "-NoProfile -ExecutionPolicy Bypass -Command ""Get-Process uxplay-windows,uxplay-bluetooth-beacon,scrcpy,adb -ErrorAction SilentlyContinue | Stop-Process -Force; Remove-NetFirewallRule -DisplayName 'AirShare*' -ErrorAction SilentlyContinue"""; Flags: runhidden waituntilterminated; RunOnceId: "AirShareCleanup"

[Code]
// Tutup adb/scrcpy yang masih jalan supaya file di {app}\scrcpy bisa diganti saat update.
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  R: Integer;
begin
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM scrcpy.exe /IM adb.exe', '', SW_HIDE, ewWaitUntilTerminated, R);
  Result := '';
end;
