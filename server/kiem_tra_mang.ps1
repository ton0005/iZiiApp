# kiem_tra_mang.ps1 — Chẩn đoán "điện thoại không kết nối được server"
#
# CHẠY BẰNG QUYỀN ADMIN: chuột phải → Run with PowerShell (as Administrator)
#
# VÌ SAO CÓ FILE NÀY: log ngày 13/08 cho thấy hai phiên server cuối cùng chỉ
# nhận request từ 127.0.0.1 — không một gói nào từ iPhone/iPad, trong khi
# server bind đúng 0.0.0.0:8080. Gói tin bị chặn hoặc đi sai địa chỉ trước khi
# tới được ứng dụng, nên log server không thể ghi lại gì.
#
# Script này kiểm tra ba nguyên nhân theo thứ tự khả năng:
#   1. Tường lửa Windows chặn cổng vào
#   2. Card mạng đang ở hồ sơ "Public" (Windows chặn gần hết kết nối vào)
#   3. Điện thoại đang nhập sai địa chỉ server

$ErrorActionPreference = 'Continue'
$PORT = 8080

function Head($t) {
    Write-Host ""
    Write-Host ("=" * 68) -ForegroundColor DarkGray
    Write-Host "  $t" -ForegroundColor Cyan
    Write-Host ("=" * 68) -ForegroundColor DarkGray
}

$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Head "1. Địa chỉ để nhập vào điện thoại"

$addrs = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' }

if (-not $addrs) {
    Write-Host "  Không tìm thấy địa chỉ LAN nào. Máy đã nối Wi-Fi chưa?" -ForegroundColor Red
} else {
    foreach ($a in $addrs) {
        $prof = (Get-NetConnectionProfile -InterfaceIndex $a.InterfaceIndex -ErrorAction SilentlyContinue)
        $cat  = if ($prof) { $prof.NetworkCategory } else { '?' }
        $name = if ($prof) { $prof.Name } else { $a.InterfaceAlias }

        $color = if ($cat -eq 'Public') { 'Yellow' } else { 'Green' }
        Write-Host ("  http://{0}:{1}" -f $a.IPAddress, $PORT) -ForegroundColor $color
        Write-Host ("      mạng '{0}' — hồ sơ: {1}" -f $name, $cat) -ForegroundColor DarkGray

        if ($cat -eq 'Public') {
            Write-Host "      ⚠️  Hồ sơ Public: Windows chặn hầu hết kết nối VÀO." -ForegroundColor Yellow
            Write-Host "         Đây là nguyên nhân thường gặp nhất." -ForegroundColor Yellow
        }
    }
    Write-Host ""
    Write-Host "  Nhập đúng địa chỉ của mạng Wi-Fi mà ĐIỆN THOẠI đang nối vào" -ForegroundColor White
    Write-Host "  (Settings → Sync Server trên app)." -ForegroundColor White
}

Head "2. Tường lửa Windows"

$rules = Get-NetFirewallRule -DisplayName "iZiiApp Server*" -ErrorAction SilentlyContinue
if ($rules) {
    Write-Host "  Đã có luật cho iZiiApp:" -ForegroundColor Green
    $rules | ForEach-Object { Write-Host ("    - {0}  [{1}]" -f $_.DisplayName, $_.Enabled) }
} else {
    Write-Host "  CHƯA có luật mở cổng $PORT cho iZiiApp." -ForegroundColor Yellow
    if ($isAdmin) {
        Write-Host "  Đang tạo..." -ForegroundColor White
        try {
            New-NetFirewallRule -DisplayName "iZiiApp Server ($PORT/TCP)" `
                -Direction Inbound -Protocol TCP -LocalPort $PORT `
                -Action Allow -Profile Any | Out-Null
            # mDNS: để điện thoại tự tìm thấy server, không phải gõ IP bằng tay.
            New-NetFirewallRule -DisplayName "iZiiApp Server (mDNS 5353/UDP)" `
                -Direction Inbound -Protocol UDP -LocalPort 5353 `
                -Action Allow -Profile Any | Out-Null
            Write-Host "  ✅ Đã mở cổng $PORT/TCP và 5353/UDP." -ForegroundColor Green
        } catch {
            Write-Host "  ❌ Không tạo được luật: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  → Chạy lại script này bằng quyền Administrator để tự mở." -ForegroundColor Yellow
        Write-Host "  → Hoặc chạy tay:" -ForegroundColor DarkGray
        Write-Host "     New-NetFirewallRule -DisplayName 'iZiiApp Server' -Direction Inbound ``" -ForegroundColor DarkGray
        Write-Host "        -Protocol TCP -LocalPort $PORT -Action Allow -Profile Any" -ForegroundColor DarkGray
    }
}

Head "3. Server có đang chạy và lắng nghe không"

$listen = Get-NetTCPConnection -LocalPort $PORT -State Listen -ErrorAction SilentlyContinue
if ($listen) {
    foreach ($l in $listen) {
        $p = Get-Process -Id $l.OwningProcess -ErrorAction SilentlyContinue
        Write-Host ("  ✅ Đang lắng nghe {0}:{1}  (tiến trình: {2})" -f `
            $l.LocalAddress, $l.LocalPort, $(if ($p) { $p.ProcessName } else { $l.OwningProcess })) -ForegroundColor Green
    }
    if (-not ($listen | Where-Object { $_.LocalAddress -eq '0.0.0.0' -or $_.LocalAddress -eq '::' })) {
        Write-Host "  ⚠️  Chỉ lắng nghe trên localhost — máy khác KHÔNG vào được." -ForegroundColor Yellow
    }
} else {
    Write-Host "  ❌ Không có gì lắng nghe ở cổng $PORT. Server chưa chạy?" -ForegroundColor Red
}

Head "4. Việc cần làm trên điện thoại"

Write-Host @"
  Mở TRÌNH DUYỆT trên điện thoại (không phải app), vào:

        http://<địa-chỉ-ở-mục-1>:$PORT/sync/status

  • Ra JSON  → mạng thông, vấn đề nằm trong app (kiểm tra Settings → Sync Server).
  • Không ra → điện thoại KHÔNG tới được server. Kiểm tra theo thứ tự:
       - Điện thoại và laptop có cùng một Wi-Fi không?
       - Đã chạy script này bằng quyền Admin để mở tường lửa chưa?
       - Điểm phát Wi-Fi có bật 'cách ly thiết bị' (AP isolation) không?

  Chưa qua được bước này thì đăng ký thiết bị, đồng bộ và gọi điện đều
  không thể hoạt động — cả ba đều cần tới server.
"@ -ForegroundColor White

Write-Host ""
