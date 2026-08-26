<#
.SYNOPSIS
    Script tự động tải vc_redist.x64.exe và biên dịch bộ cài đặt Inno Setup cho iZiiApp.
#>

[CmdletBinding()]
param (
    [switch]$SkipDownloadRedist,
    [switch]$AutoInstallInnoSetup
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

# 1. Kiểm tra thư mục Release
if (-not (Test-Path (Join-Path $ReleaseDir "izii_app.exe"))) {
    Write-Host "⚠️  Không tìm thấy bản build Release tại: $ReleaseDir" -ForegroundColor Yellow
    Write-Host "Đang tiến hành build Flutter Release cho Windows..." -ForegroundColor Yellow
    Push-Location $ProjectRoot
    try {
        flutter build windows --release
    }
    finally {
        Pop-Location
    }
    if (-not (Test-Path (Join-Path $ReleaseDir "izii_app.exe"))) {
        Write-Host "❌ Build Flutter thất bại. Vui lòng kiểm tra lại môi trường Flutter." -ForegroundColor Red
        exit 1
    }
}
Write-Host "✅ Đã tìm thấy bản build Release iZiiApp." -ForegroundColor Green

# 2. Tự động tải vc_redist.x64.exe nếu chưa có
if (-not (Test-Path $RedistDir)) {
    New-Item -ItemType Directory -Path $RedistDir -Force | Out-Null
}

if (-not (Test-Path $VcRedistExe) -and (-not $SkipDownloadRedist)) {
    Write-Host "⬇️  Đang tải Microsoft Visual C++ 2015-2022 Redistributable (x64)..." -ForegroundColor Yellow
    $VcRedistUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    Invoke-WebRequest -Uri $VcRedistUrl -OutFile $VcRedistExe
    Write-Host "✅ Đã tải xong: $VcRedistExe" -ForegroundColor Green
} else {
    Write-Host "✅ Đã có sẵn tệp vc_redist.x64.exe" -ForegroundColor Green
}

# 3. Tìm trình biên dịch Inno Setup (ISCC.exe)
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
    Write-Host "⚠️  Chưa tìm thấy phần mềm Inno Setup 6 (ISCC.exe) trên máy." -ForegroundColor Yellow
    Write-Host "Đang tự động cài đặt Inno Setup qua winget..." -ForegroundColor Cyan
    try {
        winget install JRSoftware.InnoSetup -e --silent --accept-source-agreements --accept-package-agreements
        # Thử dò lại sau khi cài
        foreach ($path in $IsccCandidates) {
            if (Test-Path $path) {
                $IsccPath = $path
                break
            }
        }
    }
    catch {
        Write-Host "⚠️ Không thể tự cài Inno Setup qua winget." -ForegroundColor Yellow
    }

    if (-not $IsccPath) {
        Write-Host "👉 Vui lòng tải và cài đặt Inno Setup miễn phí tại: https://jrsoftware.org/isdl.php" -ForegroundColor Cyan
        Write-Host "   Sau khi cài xong, chạy lại script này." -ForegroundColor Cyan
        exit 1
    }
}

Write-Host "🔨 Sử dụng Inno Setup Compiler: $IsccPath" -ForegroundColor Green

# 4. Biên dịch bộ cài đặt
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

Write-Host "🚀 Đang biên dịch bộ cài đặt Setup..." -ForegroundColor Cyan
Push-Location $ScriptDir
try {
    & $IsccPath $IssFile
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "=====================================================" -ForegroundColor Green
        Write-Host "🎉 BIÊN DỊCH BỘ CÀI ĐẶT THÀNH CÔNG!" -ForegroundColor Green
        Write-Host "📁 File cài đặt nằm tại: $OutputDir" -ForegroundColor Green
        Write-Host "=====================================================" -ForegroundColor Green
        Get-ChildItem -Path $OutputDir -Filter "*.exe" | ForEach-Object {
            $sizeMB = [math]::Round($_.Length / 1MB, 2)
            Write-Host "   • $($_.Name) ($sizeMB MB)" -ForegroundColor Cyan
        }
    } else {
        Write-Host "❌ Quá trình biên dịch gặp lỗi." -ForegroundColor Red
    }
}
finally {
    Pop-Location
}
