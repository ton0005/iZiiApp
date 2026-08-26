; =====================================================================
; NSIS Script for iZiiApp (Windows x64)
; Tự động cài đặt ứng dụng và Microsoft Visual C++ 2015-2022 Redistributable
; =====================================================================

!include "MUI2.nsh"
!include "x64.nsh"
!include "FileFunc.nsh"

; Tên và phiên bản ứng dụng
Name "iZiiApp"
OutFile "Output\iZiiApp_Setup_NSIS.exe"
InstallDir "$PROGRAMFILES64\iZiiApp"
RequestExecutionLevel admin
Unicode True

; Cấu hình giao diện Modern UI
!define MUI_ABORTWARNING
!define MUI_ICON "..\runner\resources\app_icon.ico"
!define MUI_UNICON "..\runner\resources\app_icon.ico"

; Trang cài đặt
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\izii_app.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Khởi chạy iZiiApp"
!insertmacro MUI_PAGE_FINISH

; Trang gỡ cài đặt
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

Section "MainSection" SEC01
    SetOutPath "$INSTDIR"
    
    ; 1. Copy toàn bộ tệp ứng dụng iZiiApp
    File /r "..\..\build\windows\x64\runner\Release\*.*"
    
    ; 2. Cài đặt Visual C++ Redistributable (x64) nếu cần
    SetOutPath "$PLUGINSDIR"
    File "redist\vc_redist.x64.exe"
    
    DetailPrint "Đang kiểm tra và cài đặt Microsoft Visual C++ 2015-2022 Runtime..."
    ExecWait '"$PLUGINSDIR\vc_redist.x64.exe" /install /passive /norestart /quiet'
    
    ; 3. Tạo Shortcut
    CreateDirectory "$SMPROGRAMS\iZiiApp"
    CreateShortcut "$SMPROGRAMS\iZiiApp\iZiiApp.lnk" "$INSTDIR\izii_app.exe"
    CreateShortcut "$SMPROGRAMS\iZiiApp\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
    CreateShortcut "$DESKTOP\iZiiApp.lnk" "$INSTDIR\izii_app.exe"
    
    ; 4. Tạo Uninstaller
    WriteUninstaller "$INSTDIR\Uninstall.exe"
    
    ; Đăng ký trong Control Panel Add/Remove Programs
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\iZiiApp" "DisplayName" "iZiiApp"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\iZiiApp" "UninstallString" '"$INSTDIR\Uninstall.exe"'
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\iZiiApp" "DisplayIcon" "$INSTDIR\izii_app.exe"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\iZiiApp" "DisplayVersion" "1.0.4"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\iZiiApp" "Publisher" "iZiiApp Team"
SectionEnd

Section "Uninstall"
    RMDir /r "$INSTDIR"
    Delete "$DESKTOP\iZiiApp.lnk"
    RMDir /r "$SMPROGRAMS\iZiiApp"
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\iZiiApp"
SectionEnd
