<#
.SYNOPSIS
    Đưa iZiiApp trên máy Windows này về đúng trạng thái "lần đầu cài đặt".

.DESCRIPTION
    Xoá dữ liệu iZiiApp KHÔNG chỉ là xoá một file .db. Dữ liệu nằm rải ở 7 nơi
    và chỉ cần bỏ sót một chỗ là nó tự "sống lại":

      1. server\data\                     - DB server (mutation log), file đính
                                            kèm đã upload, log. Client pull với
                                            since=null se nhan lai TOAN BO lich
                                            su -> du lieu cu quay ve.
      2. %LOCALAPPDATA%\izii_app\         - DB local cua app Windows.
      3. OneDrive\Documents\izii_app_db.sqlite
                                          - DB legacy. app_database.dart tu
                                            copy file nay sang (2) khi (2)
                                            khong ton tai. DAY LA LY DO XOA DB
                                            XONG DU LIEU VAN QUAY LAI.
      4. %APPDATA%\com.izii\izii_app\     - shared_preferences.json chua
                                            last_sync_timestamp (KHONG nam
                                            trong SQLite), va kho luu tru cua
                                            flutter_secure_storage.
      5. Windows Credential Manager       - khoa dinh danh thiet bi
                                            (izii_device_id_v2, cap khoa
                                            X25519/Ed25519), cau hinh server
                                            da luu.
      6. Ban build trong dist\ va webhook_server\
                                          - moi ban build co thu muc data\
                                            rieng.
      7. Thiet bi khac (Samsung, laptop khac), server M2/CR
                                          - script KHONG voi toi duoc. Phai
                                            xoa thu cong, neu khong chung day
                                            du lieu cu nguoc len server ngay
                                            lan sync dau tien.

    Moi thu bi xoa deu duoc SAO LUU vao mot thu muc gan dau thoi gian truoc,
    nen van khoi phuc duoc neu lo tay.

.PARAMETER Force
    Bỏ qua bước hỏi xác nhận.

.PARAMETER KeepServer
    Không đụng tới dữ liệu server (chỉ reset phía client trên máy này).

.PARAMETER KeepDeviceIdentity
    Giữ lại device_id + cặp khoá trong Credential Manager. Máy sẽ tự đăng ký
    lại với server bằng danh tính cũ, không cần ghép cặp lại. Dùng khi bạn chỉ
    muốn xoá dữ liệu nghiệp vụ chứ không phải "cài lại từ đầu".

.EXAMPLE
    .\reset_data.ps1                        # wipe sach nhu lan dau cai
    .\reset_data.ps1 -KeepDeviceIdentity    # giu danh tinh thiet bi
    .\reset_data.ps1 -Force                 # khong hoi xac nhan
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$KeepServer,
    [switch]$KeepDeviceIdentity
)

$ErrorActionPreference = 'Stop'

$ServerDir = $PSScriptRoot
$Stamp     = Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupDir = Join-Path (Split-Path -Parent $ServerDir) "_reset_backup_$Stamp"

function Write-Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  [OK]   $msg" -ForegroundColor Green }
function Write-Skip($msg) { Write-Host "  [--]   $msg" -ForegroundColor DarkGray }
function Write-Warn2($msg){ Write-Host "  [!]    $msg" -ForegroundColor Yellow }

# Sao lưu rồi xoá (dùng cho cả file lẫn thư mục). Trả về $true nếu xoá thật.
function Backup-And-Remove([string]$Path, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Skip "$Label - khong ton tai."
        return $false
    }
    if (-not (Test-Path -LiteralPath $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }
    $leaf = Split-Path $Path -Leaf
    $dest = Join-Path $BackupDir ($leaf + '.' + [guid]::NewGuid().ToString('N').Substring(0, 6))
    try {
        Copy-Item -LiteralPath $Path -Destination $dest -Recurse -Force -ErrorAction Stop
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        Write-Ok "$Label - da sao luu va xoa."
        return $true
    } catch {
        Write-Warn2 "$Label - KHONG xoa duoc: $($_.Exception.Message)"
        return $false
    }
}

Write-Host @"
+--------------------------------------------------------------+
|  iZiiApp - RESET VE TRANG THAI LAN DAU CAI DAT               |
+--------------------------------------------------------------+
"@ -ForegroundColor Magenta

Write-Host "Server dir : $ServerDir"
Write-Host "Backup     : $BackupDir"
if ($KeepDeviceIdentity) { Write-Host "Che do     : GIU danh tinh thiet bi" -ForegroundColor Yellow }
else                     { Write-Host "Che do     : WIPE TOAN BO (ke ca khoa thiet bi)" -ForegroundColor Yellow }

if (-not $Force) {
    Write-Host "`nSe XOA: toan bo Job, Room, Employee, file dinh kem, thiet bi da dang ky." -ForegroundColor Yellow
    if (-not $KeepDeviceIdentity) {
        Write-Host "Va CA khoa dinh danh -> may nay se dang ky lai nhu thiet bi moi." -ForegroundColor Yellow
    }
    $answer = Read-Host "`nGo 'RESET' de xac nhan"
    if ($answer -ne 'RESET') {
        Write-Host "Da huy. Khong co gi bi thay doi." -ForegroundColor Yellow
        exit 0
    }
}

# ── 1. Dừng tiến trình đang giữ file ─────────────────────────────────────────
Write-Step "1/6  Dung cac tien trinh iZiiApp"
foreach ($n in @('izii_app', 'izii_server', 'iziiapp_server')) {
    $procs = Get-Process -Name $n -ErrorAction SilentlyContinue
    if ($procs) {
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Ok "Da dung $n ($($procs.Count) tien trinh)."
    } else {
        Write-Skip "$n khong chay."
    }
}
# Uvicorn chạy bằng python -> tìm theo cổng 8080 thay vì theo tên tiến trình.
try {
    $conn = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
    if ($conn) {
        $conn.OwningProcess | Select-Object -Unique | ForEach-Object {
            Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue
        }
        Write-Ok "Da dung tien trinh dang lang nghe cong 8080."
    } else {
        Write-Skip "Khong co gi lang nghe cong 8080."
    }
} catch { Write-Skip "Bo qua kiem tra cong 8080." }

Start-Sleep -Seconds 2   # nhường thời gian để Windows nhả file handle

# ── 2. Dữ liệu server (DB + uploads + logs) ──────────────────────────────────
Write-Step "2/6  Xoa du lieu Server (database + file dinh kem + log)"
if ($KeepServer) {
    Write-Skip "Bo qua theo tham so -KeepServer."
} else {
    # Xoá NGUYÊN thư mục data thay vì từng file .db: bên trong còn uploads\
    # (file đính kèm đã upload) và logs\. Xoá cả -wal/-shm là hệ quả tự nhiên
    # — WAL mode giữ dữ liệu chưa checkpoint ở file phụ, xoá mỗi .db là chưa
    # sạch.
    foreach ($dir in @(
        (Join-Path $ServerDir 'data'),
        (Join-Path $ServerDir 'dist\izii_server\data'),
        (Join-Path $ServerDir 'webhook_server\data')
    )) {
        [void](Backup-And-Remove $dir "Server data: $dir")
    }
    # Log cũ còn sót ở thư mục gốc của server (bản trước khi log dời vào data\logs).
    foreach ($f in @('server.log', 'testlog.txt')) {
        [void](Backup-And-Remove (Join-Path $ServerDir $f) "Server log cu: $f")
    }
}

# ── 3. Dữ liệu local của app Windows ─────────────────────────────────────────
Write-Step "3/6  Xoa du lieu local cua app Windows"
$clientRoot = Join-Path $env:LOCALAPPDATA 'izii_app'
[void](Backup-And-Remove $clientRoot "Client data: $clientRoot")

# ── 4. DB legacy trong OneDrive — thủ phạm khiến dữ liệu quay lại ────────────
Write-Step "4/6  Xoa DB legacy trong OneDrive"
$legacyDb = Join-Path $env:USERPROFILE 'OneDrive\Documents\izii_app_db.sqlite'
[void](Backup-And-Remove $legacyDb "Legacy OneDrive DB")

# Đặt lại cờ chặn app tự nạp DB legacy. Cần thiết vì OneDrive có thể đồng bộ
# file cũ từ cloud về sau khi ta vừa xoá nó ở local.
$clientDataDir = Join-Path $clientRoot 'data'
New-Item -ItemType Directory -Path $clientDataDir -Force | Out-Null
Set-Content -LiteralPath (Join-Path $clientDataDir '.legacy_migrated') -Encoding UTF8 -Value @"
Reset thuc hien luc $Stamp boi reset_data.ps1.
File co nay ngan app tu dong copy lai DB cu tu OneDrive (xem app_database.dart).
Chi xoa file nay neu ban THUC SU muon nap lai DB legacy.
"@
Write-Ok "Da dat co .legacy_migrated."

# ── 5. SharedPreferences + kho flutter_secure_storage ────────────────────────
Write-Step "5/6  Xoa cau hinh app (con tro dong bo + secure storage)"
# CompanyName/ProductName lay tu windows\runner\Runner.rc => com.izii \ izii_app
# Thu muc nay chua CA shared_preferences.json (last_sync_timestamp) LAN file
# luu tru cua flutter_secure_storage tren cac ban moi.
$appDataDir = Join-Path $env:APPDATA 'com.izii\izii_app'
if ($KeepDeviceIdentity) {
    # Chỉ xoá con trỏ sync, giữ nguyên phần secure storage.
    [void](Backup-And-Remove (Join-Path $appDataDir 'shared_preferences.json') "shared_preferences.json (con tro sync)")
    Write-Skip "Giu lai secure storage theo tham so -KeepDeviceIdentity."
} else {
    [void](Backup-And-Remove $appDataDir "App config: $appDataDir")
}

# ── 6. Windows Credential Manager ────────────────────────────────────────────
Write-Step "6/6  Xoa khoa dinh danh trong Windows Credential Manager"
if ($KeepDeviceIdentity) {
    Write-Skip "Giu lai theo tham so -KeepDeviceIdentity."
} else {
    # flutter_secure_storage tren Windows luu qua Credential Manager (ban cu)
    # hoac file DPAPI trong thu muc APPDATA o buoc 5 (ban moi). Quet ca hai cho
    # chac. Dung P/Invoke thay vi parse `cmdkey /list` vi nhan cua cmdkey doi
    # theo ngon ngu Windows -> parse chuoi rat de sai.
    $swept = 0
    try {
        if (-not ('IziiCredApi' -as [type])) {
            Add-Type -Namespace Izii -Name CredApi -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("advapi32.dll", CharSet=System.Runtime.InteropServices.CharSet.Unicode, SetLastError=true)]
public static extern bool CredEnumerateW(string filter, int flags, out int count, out System.IntPtr credentials);
[System.Runtime.InteropServices.DllImport("advapi32.dll", CharSet=System.Runtime.InteropServices.CharSet.Unicode, SetLastError=true)]
public static extern bool CredDeleteW(string target, int type, int flags);
[System.Runtime.InteropServices.DllImport("advapi32.dll", SetLastError=false)]
public static extern void CredFree(System.IntPtr buffer);
'@ -ErrorAction Stop
        }

        $count = 0; $ptr = [IntPtr]::Zero
        if ([Izii.CredApi]::CredEnumerateW($null, 0, [ref]$count, [ref]$ptr)) {
            $ptrSize = [IntPtr]::Size
            $targets = @()
            for ($i = 0; $i -lt $count; $i++) {
                $credPtr = [System.Runtime.InteropServices.Marshal]::ReadIntPtr($ptr, $i * $ptrSize)
                # CREDENTIALW: Flags(0) Type(4) TargetName(8, con tro)
                $type       = [System.Runtime.InteropServices.Marshal]::ReadInt32($credPtr, 4)
                $targetPtr  = [System.Runtime.InteropServices.Marshal]::ReadIntPtr($credPtr, 8)
                $targetName = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($targetPtr)
                if ($targetName -and $targetName -imatch 'izii') {
                    $targets += [pscustomobject]@{ Name = $targetName; Type = $type }
                }
            }
            [Izii.CredApi]::CredFree($ptr)

            foreach ($t in $targets) {
                if ([Izii.CredApi]::CredDeleteW($t.Name, $t.Type, 0)) {
                    Write-Ok "Da xoa credential: $($t.Name)"
                    $swept++
                } else {
                    Write-Warn2 "Khong xoa duoc credential: $($t.Name)"
                }
            }
        }
        if ($swept -eq 0) { Write-Skip "Khong tim thay credential nao chua 'izii'." }
    } catch {
        Write-Warn2 "Bo qua buoc quet Credential Manager: $($_.Exception.Message)"
        Write-Warn2 "Khong nghiem trong - ban moi cua flutter_secure_storage luu trong thu muc da xoa o buoc 5."
    }
}

# ── Tổng kết ────────────────────────────────────────────────────────────────
Write-Host "`n+--------------------------------------------------------------+" -ForegroundColor Magenta
Write-Host "|  HOAN TAT                                                    |" -ForegroundColor Magenta
Write-Host "+--------------------------------------------------------------+" -ForegroundColor Magenta

if (Test-Path -LiteralPath $BackupDir) {
    Write-Host "`nBan sao luu: $BackupDir" -ForegroundColor Green
    Write-Host "Xoa thu muc nay khi da chac chan khong can khoi phuc."
} else {
    Write-Host "`nKhong co file nao can sao luu (moi thu da sach tu truoc)."
}

Write-Host "`nCAC BUOC TIEP THEO - lam DUNG THU TU:" -ForegroundColor Yellow
Write-Host @"

  1. XOA DU LIEU TREN CAC THIET BI KHAC TRUOC KHI MO LAI APP.
     Bo qua buoc nay thi Samsung se day toan bo du lieu cu nguoc len server
     ngay lan sync dau tien, coi nhu chua reset gi ca.

       Android (Samsung):  Settings > Apps > iZiiApp > Storage > Clear data
       Laptop/server khac: chay chinh script nay tren may do

  2. Kiem tra khong con server M2/CR nao dang chay trong LAN.
     mDNS tu phat hien peer dong, nen mot server con du lieu se relay nguoc ve.

  3. Khoi dong lai server:
       cd "$ServerDir"
       .\run_server.bat

  4. Mo app. Lan chay dau se seed lai 66 phong o trang thai 'idle'.

"@

if (-not $KeepDeviceIdentity) {
    Write-Host "LUU Y: da xoa khoa dinh danh -> may nay se dang ky lai nhu THIET BI MOI" -ForegroundColor Yellow
    Write-Host "       (device_id moi, cap khoa E2EE moi). Cac thiet bi khac se thay" -ForegroundColor Yellow
    Write-Host "       day la mot thiet bi la va can xac nhan lai neu co buoc ghep cap." -ForegroundColor Yellow
}

Write-Host "`nMEO: neu server dang chay va ban khong muon dung no, co the reset" -ForegroundColor DarkGray
Write-Host "     rieng phia server bang API:" -ForegroundColor DarkGray
Write-Host @"
     `$h = @{ 'X-iZii-Server-Token' = '<IZIIAPP_SERVER_SECRET trong .env>' }
     `$b = @{ confirm = '<IZIIAPP_SERVER_ID trong .env>' } | ConvertTo-Json
     Invoke-RestMethod -Uri http://localhost:8080/admin/reset -Method Post ``
                       -Headers `$h -Body `$b -ContentType 'application/json'
"@ -ForegroundColor DarkGray
