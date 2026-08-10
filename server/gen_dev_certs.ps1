<#
.SYNOPSIS
    Sinh CA nội bộ + chứng chỉ cho từng server iZii, phục vụ mTLS (mục 6.4).

.DESCRIPTION
    Tạo trong thư mục server\certs\:
        izii-ca.crt / izii-ca.key   - CA nội bộ, ký cho mọi server
        <server-id>.crt / .key      - chứng chỉ từng server

    Common Name của mỗi chứng chỉ chính là server_id (server-m1, server-m2,
    server-cr) — khớp với IZIIAPP_TLS_ALLOWED_PEER_CNS bên .env.

    SubjectAltName gồm cả IP lẫn DNS name. BẮT BUỘC phải có: từ khoảng 2017
    các thư viện TLS hiện đại (bao gồm Python ssl) BỎ QUA CN khi kiểm tra
    hostname và chỉ đọc SAN. Thiếu SAN thì httpx sẽ báo lỗi xác thực dù chứng
    chỉ hoàn toàn hợp lệ.

    ⚠️ Đây là chứng chỉ TỰ KÝ dùng cho LAN nội bộ và môi trường thử nghiệm.
    Với hệ thống nối SAP thật, hãy dùng CA của doanh nghiệp.

.PARAMETER Servers
    Danh sách "server-id=IP". Mặc định là 3 server M1/M2/CR.

.PARAMETER Days
    Số ngày hiệu lực. Mặc định 825 (giới hạn nhiều client áp dụng).

.EXAMPLE
    .\gen_dev_certs.ps1
    .\gen_dev_certs.ps1 -Servers @('server-m1=192.168.1.10','server-m2=192.168.1.11')
#>

[CmdletBinding()]
param(
    [string[]]$Servers = @(
        'server-m1=192.168.1.10',
        'server-m2=192.168.1.11',
        'server-cr=192.168.1.12'
    ),
    [int]$Days = 825
)

$ErrorActionPreference = 'Stop'

$CertDir = Join-Path $PSScriptRoot 'certs'

function Write-Ok($m)  { Write-Host "  [OK]  $m" -ForegroundColor Green }
function Write-Info($m){ Write-Host "  [..]  $m" -ForegroundColor Cyan }

# ── Kiểm tra openssl ────────────────────────────────────────────────────────
$openssl = Get-Command openssl -ErrorAction SilentlyContinue
if (-not $openssl) {
    Write-Host @"
Khong tim thay 'openssl' trong PATH.

Cach cai nhanh nhat tren Windows - dung ban di kem Git:
    C:\Program Files\Git\usr\bin\openssl.exe
Them thu muc do vao PATH, hoac chay lai script tu 'Git Bash'.

Hoac cai qua winget:
    winget install ShiningLight.OpenSSL.Light
"@ -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Path $CertDir -Force | Out-Null
Write-Host "`nThu muc chung chi: $CertDir`n" -ForegroundColor Magenta

$caKey = Join-Path $CertDir 'izii-ca.key'
$caCrt = Join-Path $CertDir 'izii-ca.crt'

# ── 1. CA nội bộ ────────────────────────────────────────────────────────────
if ((Test-Path $caCrt) -and (Test-Path $caKey)) {
    Write-Info "CA da ton tai, dung lai (khong tao moi de khong lam hong cac cert da ky)."
} else {
    Write-Info 'Tao CA noi bo...'
    & openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes `
        -keyout $caKey -out $caCrt `
        -subj "/C=AU/ST=SA/O=iZiiApp/CN=iZii Internal CA" 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Tao CA that bai." }
    Write-Ok "izii-ca.crt / izii-ca.key"
}

# ── 2. Chứng chỉ cho từng server ────────────────────────────────────────────
foreach ($entry in $Servers) {
    $parts = $entry -split '=', 2
    $id = $parts[0].Trim()
    $ip = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '127.0.0.1' }

    Write-Info "Tao chung chi cho $id ($ip)..."

    $key = Join-Path $CertDir "$id.key"
    $csr = Join-Path $CertDir "$id.csr"
    $crt = Join-Path $CertDir "$id.crt"
    $ext = Join-Path $CertDir "$id.ext"

    # SAN bao gom IP, ten mDNS (<id>.local) va localhost de test tren may.
    @"
subjectAltName = IP:$ip, IP:127.0.0.1, DNS:$id, DNS:$id.local, DNS:localhost
extendedKeyUsage = serverAuth, clientAuth
keyUsage = digitalSignature, keyEncipherment
"@ | Set-Content -LiteralPath $ext -Encoding ascii

    & openssl req -newkey rsa:2048 -sha256 -nodes `
        -keyout $key -out $csr `
        -subj "/C=AU/ST=SA/O=iZiiApp/CN=$id" 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Tao CSR cho $id that bai." }

    & openssl x509 -req -in $csr -CA $caCrt -CAkey $caKey -CAcreateserial `
        -out $crt -days $Days -sha256 -extfile $ext 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Ky chung chi cho $id that bai." }

    Remove-Item -LiteralPath $csr, $ext -Force -ErrorAction SilentlyContinue
    Write-Ok "$id.crt / $id.key  (CN=$id, SAN gom IP:$ip)"
}

# ── 3. Hướng dẫn ────────────────────────────────────────────────────────────
$firstId = ($Servers[0] -split '=')[0].Trim()

Write-Host @"

+--------------------------------------------------------------+
|  HOAN TAT                                                    |
+--------------------------------------------------------------+

BUOC TIEP THEO

1. Tren MOI may, copy vao server\certs\ :
       izii-ca.crt          (giong nhau tren moi may)
       <server-id>.crt/.key (RIENG cua may do - KHONG dung chung)

   File .key la KHOA BI MAT. Khong commit, khong gui qua chat.

2. Them vao .env cua tung may:

       IZIIAPP_TLS_CERT_FILE=certs/$firstId.crt
       IZIIAPP_TLS_KEY_FILE=certs/$firstId.key
       IZIIAPP_TLS_CA_FILE=certs/izii-ca.crt
       IZIIAPP_TLS_REQUIRE_CLIENT_CERT=true
       IZIIAPP_TLS_ALLOWED_PEER_CNS=$(($Servers | ForEach-Object { ($_ -split '=')[0] }) -join ',')

3. Doi IZIIAPP_PEERS sang https:// (khong con http://).

4. BAT DONG LOAT tren ca 3 may. Ghep http voi https se lam peer-sync
   that bai o buoc bat tay ma khong co loi ro rang.

5. Kiem tra:
       curl.exe --cacert certs/izii-ca.crt ``
                --cert certs/$firstId.crt --key certs/$firstId.key ``
                -H "X-iZii-Server-Token: <secret>" ``
                https://<ip-peer>:8080/peer-sync/health

LUU Y: them 'certs/' vao .gitignore.

"@ -ForegroundColor Yellow
