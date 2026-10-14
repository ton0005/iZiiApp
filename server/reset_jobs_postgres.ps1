<#
.SYNOPSIS
    Reset du lieu Job (Nhiem vu, Cong viec, Ca lam) tren PostgreSQL va he thong dong bo iZiiApp.

.DESCRIPTION
    Script nay dua tren nguyen ly cua reset_data.ps1 nhung CHUYEN BIET cho du lieu JOB
    tren backend PostgreSQL va co che dong bo dong bo phan tan (sync mutations):

    VI SAO XOA BANG 'mushroom_jobs' LA CHUA DU:
      1. PostgreSQL sync_mutations:
         Server luu toan bo lich su thay doi (mutation log). Neu chi xoa bang
         'mushroom_jobs' ma KHONG xoa mutations tuong ung trong 'sync_mutations',
         bat ky client nao goi /sync/pull se nhan lai toan bo Job cu -> du lieu
         tu dong "song lai".
      2. Client local DB (Windows / Android / iOS):
         Neu may Windows hoac dien thoai van con giu Job trong SQLite local, ngay
         lan sync tiep theo (/sync/push), client se day nguoc toan bo Job cu len lai server.
      3. Bang lien quan:
         Job con di kem voi tasks, mushroom_job_safety_configs, mushroom_safety_checkin_logs,
         va tuy chon cac bang diem danh, ca lam viec (mushroom_attendance_events,
         mushroom_daily_timesheets, mushroom_shifts).

    TAT CA DU LIEU DEU DUOC SAO LUU (JSON & SQLite) truoc khi thuc hien xoa.

.PARAMETER Force
    Bo qua buoc hoi xac nhan 'RESET'.

.PARAMETER KeepClient
    Chi reset tren server PostgreSQL, khong dung toi SQLite local cua Windows app.

.PARAMETER IncludeAttendance
    Xoa kem ca du lieu diem danh, ca lam, timesheets va bang luong lien quan toi Job.

.PARAMETER PgDsn
    Chuoi ket noi PostgreSQL (mac dinh doc tu server/.env).

.PARAMETER DryRun
    Chi chay thu: ket noi, dem ban ghi va tao file sao luu; KHONG xoa du lieu that.

.EXAMPLE
    .\reset_jobs_postgres.ps1
    .\reset_jobs_postgres.ps1 -Force
    .\reset_jobs_postgres.ps1 -IncludeAttendance
    .\reset_jobs_postgres.ps1 -KeepClient
    .\reset_jobs_postgres.ps1 -DryRun
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$KeepClient,
    [switch]$IncludeAttendance,
    [string]$PgDsn,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$ServerDir = $PSScriptRoot
$Stamp     = Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupDir = Join-Path (Split-Path -Parent $ServerDir) "_reset_jobs_backup_$Stamp"

function Write-Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  [OK]   $msg" -ForegroundColor Green }
function Write-Skip($msg) { Write-Host "  [--]   $msg" -ForegroundColor DarkGray }
function Write-Warn2($msg){ Write-Host "  [!]    $msg" -ForegroundColor Yellow }

Write-Host @"
+--------------------------------------------------------------+
|  iZiiServer - RESET DU LIEU JOB TREN POSTGRESQL              |
+--------------------------------------------------------------+
"@ -ForegroundColor Magenta

Write-Host "Server dir : $ServerDir"
Write-Host "Backup dir : $BackupDir"
Write-Host "Attendance : $(if ($IncludeAttendance) { 'CO (xoa ca diem danh & ca lam)' } else { 'KHONG (chi Job & Task)' })" -ForegroundColor Yellow
Write-Host "Client     : $(if ($KeepClient) { 'GIU NGUYEN Client SQLite' } else { 'DON CA Client SQLite local' })" -ForegroundColor Yellow
if ($DryRun) { Write-Host "Che do     : DRY-RUN (khong thuc hien xoa)" -ForegroundColor Cyan }

if (-not $Force -and -not $DryRun) {
    Write-Host "`nCANH BAO: Script se XOA TOAN BO cac bang Job tren PostgreSQL va sync_mutations." -ForegroundColor Yellow
    if ($IncludeAttendance) {
        Write-Host "Cung nhu cac bang: attendance_events, daily_timesheets, shifts, payroll." -ForegroundColor Yellow
    }
    if (-not $KeepClient) {
        Write-Host "Va se don sach Job trong local DB cua Windows app (de tranh sync nguoc len server)." -ForegroundColor Yellow
    }
    Write-Host "Tat ca du lieu deu duoc backup truoc vao: $BackupDir" -ForegroundColor Green
    $answer = Read-Host "`nGo 'RESET' de xac nhan"
    if ($answer -ne 'RESET') {
        Write-Host "Da huy thao tac. Khong co du lieu nao bi thay doi." -ForegroundColor Yellow
        exit 0
    }
}

# ── 1. Dung cac tien trinh iZiiApp dang chay ─────────────────────────────────
Write-Step "1/4  Kiem tra va dung cac tien trinh iZiiApp"
foreach ($n in @('izii_app', 'izii_server', 'iziiapp_server')) {
    $procs = Get-Process -Name $n -ErrorAction SilentlyContinue
    if ($procs) {
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Ok "Da dung $n ($($procs.Count) tien trinh)."
    } else {
        Write-Skip "$n khong chay."
    }
}
# Kiem tra cong 8080 (uvicorn standalone)
try {
    $conn = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
    if ($conn) {
        $conn.OwningProcess | Select-Object -Unique | ForEach-Object {
            Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue
        }
        Write-Ok "Da dung tien trinh dang lang nghe cong 8080."
    } else {
        Write-Skip "Khong co tien trinh nao lang nghe cong 8080."
    }
} catch {
    Write-Skip "Bo qua kiem tra cong 8080."
}

Start-Sleep -Seconds 1

# ── 2. Tao thu muc sao luu ──────────────────────────────────────────────────
Write-Step "2/4  Chuan bi thu muc sao luu"
if (-not (Test-Path -LiteralPath $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}
Write-Ok "Thu muc sao luu: $BackupDir"

# ── 3. Chay Python Engine reset PostgreSQL & Sync Mutations ─────────────────
Write-Step "3/4  Thuc hien sao luu va reset Job tren PostgreSQL"
$pyScript = Join-Path $ServerDir 'reset_jobs_pg.py'
if (-not (Test-Path -LiteralPath $pyScript)) {
    Write-Error "Khong tim thay file dong hanh: $pyScript"
    exit 1
}

$pyArgs = @("`"$pyScript`"", "--backup-dir", "`"$BackupDir`"")
if ($PgDsn) {
    $pyArgs += @("--dsn", "`"$PgDsn`"")
}
if ($IncludeAttendance) {
    $pyArgs += "--include-attendance"
}
if (-not $KeepClient) {
    $pyArgs += "--clean-client"
}
if ($DryRun) {
    $pyArgs += "--dry-run"
}

$cmd = "python " + ($pyArgs -join " ")
Write-Host "Dang thuc thi: $cmd" -ForegroundColor DarkGray
& python $pyArgs

if ($LASTEXITCODE -ne 0) {
    Write-Warn2 "Qua trinh reset bang Python ket thuc voi ma loi: $LASTEXITCODE"
    exit $LASTEXITCODE
}

# ── 4. Dat lai con tro dong bo Client (SharedPreferences) ───────────────────
Write-Step "4/4  Cap nhat con tro dong bo Client Windows"
if ($KeepClient) {
    Write-Skip "Bo qua theo tham so -KeepClient."
} else {
    $sharedPrefsPath = Join-Path $env:APPDATA 'com.izii\izii_app\shared_preferences.json'
    if (Test-Path -LiteralPath $sharedPrefsPath) {
        try {
            $dest = Join-Path $BackupDir "shared_preferences_backup.json"
            Copy-Item -LiteralPath $sharedPrefsPath -Destination $dest -Force
            if (-not $DryRun) {
                # Xoa file de app keo state sach tu server o lan khoi dong sau
                Remove-Item -LiteralPath $sharedPrefsPath -Force
                Write-Ok "Da sao luu va reset shared_preferences.json (con tro sync)."
            } else {
                Write-Ok "Da sao luu shared_preferences.json (DRY-RUN: khong xoa)."
            }
        } catch {
            Write-Warn2 "Khong the reset shared_preferences.json: $($_.Exception.Message)"
        }
    } else {
        Write-Skip "Khong tim thay shared_preferences.json."
    }
}

# ── Tong ket ────────────────────────────────────────────────────────────────
Write-Host "`n+--------------------------------------------------------------+" -ForegroundColor Magenta
Write-Host "|  HOAN TAT RESET JOB DATA                                     |" -ForegroundColor Magenta
Write-Host "+--------------------------------------------------------------+" -ForegroundColor Magenta

Write-Host "`nThu muc sao luu: $BackupDir" -ForegroundColor Green
Write-Host "   (Chua file postgres_jobs_backup.json va ban sao SQLite local)"

Write-Host "`nCAC BUOC TIEP THEO:" -ForegroundColor Yellow
Write-Host @"

  1. DON SACH DU LIEU TREN CAC THIET BI KHAC (Samsung, iPhone/iPad):
     Neu thiet bi khac (nhu dien thoai kiem dem, tablet phong nam) dang giu
     du lieu Job cu trong bo nho, ngay khi mo app chung se push nguoc Job cu
     len lai server PostgreSQL!
       - Android: Settings > Apps > iZiiApp > Storage > Clear Data
       - iOS: Xoa ung dung va cai lai, hoac chon 'Reset Local Cache' trong app.

  2. KHOI DONG LAI SERVER:
       cd "$ServerDir"
       .\run_server.bat (hoac chay binary dist\izii_server)

  3. MO LAI APP TREN WINDOWS:
       App se dong bo trang thai moi tinh (0 jobs) tu PostgreSQL.

"@
