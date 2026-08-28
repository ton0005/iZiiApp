; =====================================================================
; Inno Setup Script for iZiiApp (Windows Desktop x64)
; Tự động cài đặt ứng dụng và Microsoft Visual C++ 2015-2022 Redistributable
; =====================================================================

#define MyAppName "iZiiApp"
#define MyAppVersion "1.0.4"
#define MyAppPublisher "iZiiApp Team"
#define MyAppURL "https://iziiapp.com"
#define MyAppExeName "izii_app.exe"
#define BuildOutputDir "..\..\build\windows\x64\runner\Release"
#define RedistDir "redist"

[Setup]
; Thông tin ứng dụng cơ bản
AppId={{D37F8E41-8B39-4E6C-9A52-2A71F9D4E21C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Đường dẫn cài đặt mặc định (Program Files\iZiiApp)
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

; Quyền quản trị (Bắt buộc để cài VC++ Redistributable toàn hệ thống)
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible

; Giao diện & Tệp đầu ra
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir=Output
OutputBaseFilename=iZiiApp_Setup_v{#MyAppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern

; Ngôn ngữ cài đặt
[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[Files]
; 1. Toàn bộ tệp ứng dụng iZiiApp từ thư mục Flutter Release
Source: "{#BuildOutputDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; 2. Gói Visual C++ 2015-2022 Redistributable x64 (Lưu vào thư mục tạm của Setup)
Source: "{#RedistDir}\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: ignoreversion deleteafterinstall

[Icons]
Name: "{autoprograms}\{#MyAppName}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autoprograms}\{#MyAppName}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Tự động cài đặt VC++ Redistributable trong chế độ im lặng nếu máy tính chưa có
Filename: "{tmp}\vc_redist.x64.exe"; \
    Parameters: "/install /passive /norestart /quiet"; \
    StatusMsg: "Đang cài đặt Microsoft Visual C++ Runtime (x64)..."; \
    Flags: waituntilterminated runhidden; \
    Check: VCRedistNeedsInstall

; Tuỳ chọn khởi chạy iZiiApp sau khi hoàn tất cài đặt
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// Hàm kiểm tra máy tính đã cài đặt Visual C++ 2015-2022 x64 hay chưa
function VCRedistNeedsInstall: Boolean;
var
  Installed: Cardinal;
  Bld: Cardinal;
begin
  Result := True;
  
  // Kiểm tra Registry của Visual C++ 2015-2022 (v14.0) x64
  if RegQueryDWordValue(HKLM64, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64', 'Installed', Installed) then
  begin
    if Installed = 1 then
    begin
      // Đã cài đặt VC++ 14.x x64, kiểm tra tiếp build version tối thiểu
      if RegQueryDWordValue(HKLM64, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64', 'Bld', Bld) then
      begin
        // Build >= 24215 (Visual C++ 2015 Update 3 trở lên)
        if Bld >= 24215 then
          Result := False;
      end
      else
        Result := False;
    end;
  end;
end;
