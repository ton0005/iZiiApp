<#
.SYNOPSIS
    Script tu dong kiem tra, build Flutter Release (neu can), tai vc_redist.x64.exe va bien dich bo cai dat Inno Setup cho iZiiApp.
#>

[CmdletBinding()]
param (
    [switch]$RebuildFlutter,
    [switch]$SkipDownloadRedist,
    [switch]$AutoInstallInnoSetup,
    [string]$AppVersion = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..\..")
$ReleaseDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
$RedistDir = Join-Path $ScriptDir "redist"
$VcRedistExe = Join-Path $RedistDir "vc_redist.x64.exe"
$IssFile = Join-Path $ScriptDir "izii_app_setup.iss"
$OutputDir = Join-Path $ScriptDir "Output"

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "   iZiiApp Windows Installer Builder (Inno Setup)   " -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan

# Tim lenh Flutter
$FlutterCmd = "flutter"
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    if (Test-Path "C:\flutter\bin\flutter.bat") {
        $FlutterCmd = "C:\flutter\bin\flutter.bat"
    } elseif (Test-Path "$env:LOCALAPPDATA\flutter\bin\flutter.bat") {
        $FlutterCmd = "$env:LOCALAPPDATA\flutter\bin\flutter.bat"
    }
}

# 1. Kiem tra thu muc Release hoac yeu cau Rebuild
$NeedBuildFlutter = $RebuildFlutter.IsPresent -or (-not (Test-Path (Join-Path $ReleaseDir "izii_app.exe")))

if ($NeedBuildFlutter) {
    Write-Host "[BUILD] Dang tien hanh bien dich Flutter Windows Release..." -ForegroundColor Yellow
    Push-Location $ProjectRoot
    try {
        & $FlutterCmd build windows --release
    }
    finally {
        Pop-Location
    }
    if (-not (Test-Path (Join-Path $ReleaseDir "izii_app.exe"))) {
        Write-Host "[ERROR] Build Flutter that bai. Vui long kiem tra lai moi truong Flutter." -ForegroundColor Red
        exit 1
    }
    Write-Host "[OK] Da build Flutter Release thanh cong." -ForegroundColor Green
} else {
    Write-Host "[OK] Da co san ban build Release iZiiApp." -ForegroundColor Green
}

# 2. Tu dong tai vc_redist.x64.exe neu chua co
if (-not (Test-Path $RedistDir)) {
    New-Item -ItemType Directory -Path $RedistDir -Force | Out-Null
}

if ((-not (Test-Path $VcRedistExe)) -and (-not $SkipDownloadRedist)) {
    Write-Host "[DOWNLOAD] Dang tai Microsoft Visual C++ 2015-2022 Redistributable (x64)..." -ForegroundColor Yellow
    $VcRedistUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    Invoke-WebRequest -Uri $VcRedistUrl -OutFile $VcRedistExe
    Write-Host "[OK] Da tai xong: $VcRedistExe" -ForegroundColor Green
} else {
    Write-Host "[OK] Da co san tep vc_redist.x64.exe" -ForegroundColor Green
}

# 3. Tim trinh bien dich Inno Setup (ISCC.exe)
$IsccCandidates = @(
    "ISCC.exe",
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
)

$IsccPath = $null
foreach ($path in $IsccCandidates) {
    if (Get-Command $path -ErrorAction SilentlyContinue) {
        $IsccPath = $path
        break
    }
    if (Test-Path $path) {
        $IsccPath = $path
        break
    }
}

if (-not $IsccPath) {
    Write-Host "[WARN] Chua tim thay phan mem Inno Setup 6 (ISCC.exe) tren may." -ForegroundColor Yellow
    Write-Host "[INFO] Dang tu dong cai dat Inno Setup qua winget..." -ForegroundColor Cyan
    try {
        winget install JRSoftware.InnoSetup -e --silent --accept-source-agreements --accept-package-agreements
        foreach ($path in $IsccCandidates) {
            if (Test-Path $path) {
                $IsccPath = $path
                break
            }
        }
    }
    catch {
        Write-Host "[WARN] Khong the tu cai Inno Setup qua winget." -ForegroundColor Yellow
    }

    if (-not $IsccPath) {
        Write-Host "[INFO] Vui long tai va cai dat Inno Setup mien phi tai: https://jrsoftware.org/isdl.php" -ForegroundColor Cyan
        exit 1
    }
}

Write-Host "[OK] Su dung Inno Setup Compiler: $IsccPath" -ForegroundColor Green

# 4. Bien dich bo cai dat
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

Write-Host "[PACKAGE] Dang bien dich bo cai dat Setup bang Inno..." -ForegroundColor Cyan
Push-Location $ScriptDir
try {
    $IsccArgs = @()
    if ($AppVersion) {
        $IsccArgs += "/DMyAppVersion=$AppVersion"
    }
    $IsccArgs += $IssFile

    & $IsccPath @IsccArgs
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "=====================================================" -ForegroundColor Green
        Write-Host "[SUCCESS] BIEN DICH BO CAI DAT THÀNH CONG!" -ForegroundColor Green
        Write-Host "[DIR] File cai dat nam tai: $OutputDir" -ForegroundColor Green
        Write-Host "=====================================================" -ForegroundColor Green
        Get-ChildItem -Path $OutputDir -Filter "*.exe" | Sort-Object LastWriteTime -Descending | ForEach-Object {
            $sizeMB = [math]::Round($_.Length / 1MB, 2)
            $lastMod = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            Write-Host "   * $($_.Name) ($sizeMB MB - $lastMod)" -ForegroundColor Cyan
        }
    } else {
        Write-Host "[ERROR] Qua trinh bien dich gap loi." -ForegroundColor Red
        exit 1
    }
}
finally {
    Pop-Location
}
