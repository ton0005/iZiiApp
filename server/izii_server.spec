# -*- mode: python ; coding: utf-8 -*-
"""
PyInstaller spec DUY NHẤT cho iZiiServer.

Trước đây dự án có 2 spec, mỗi cái thiếu một nửa:
  - server/izii_server.spec      : có zeroconf, thiếu websockets
  - iziiapp_server.spec (gốc)    : có websockets + httpx, THIẾU HẲN zeroconf
File này gộp cả hai. Spec ở thư mục gốc đã bị vô hiệu hoá, đừng dùng lại.

CÁCH BUILD — phải chạy TỪ TRONG thư mục server/:
    cd server
    pyinstaller --noconfirm izii_server.spec
Kết quả: server/dist/izii_server/izii_server.exe  (đúng đường dẫn mà
run_izii_server.bat đang tìm).

VÌ SAO ONE-DIR CHỨ KHÔNG ONE-FILE:
one-file giải nén toàn bộ vào thư mục tạm mỗi lần khởi động — chậm, và
zeroconf/mDNS hay lỗi khi bind socket từ thư mục tạm. one-dir khởi động nhanh
hơn và dễ thay .env / xem log hơn.

LƯU Ý VỀ .env: spec này CỐ Ý không đóng gói .env vào bản build — secret không
nên nằm trong artifact. run_izii_server.bat sẽ tự copy server\.env sang cạnh
file .exe. Khi chạy dạng frozen, server_config._load_env_file() đọc
dirname(sys.executable)/.env.
"""
from PyInstaller.utils.hooks import collect_all

datas = []
binaries = []
hiddenimports = []


# ── Gói cần collect_all ──────────────────────────────────────────────────────
# collect_all lấy cả submodule, file dữ liệu và binary (.pyd) — bắt buộc với
# những package mà PyInstaller không truy vết tĩnh được.
for _pkg in (
    # zeroconf: có submodule biên dịch bằng Cython (_dns, _protocol.incoming,
    # _utils.ipaddress, ...) nạp động lúc runtime. Thiếu cái này thì mDNS chết
    # ÂM THẦM — app.py bọc start_advertising/start_discovery trong try/except
    # nên server vẫn chạy, chỉ mất auto-discovery mà không ai để ý.
    'zeroconf',
    # certifi: httpx cần file CA bundle (cacert.pem) để gọi webhook HTTPS.
    'certifi',
):
    _ret = collect_all(_pkg)
    datas += _ret[0]
    binaries += _ret[1]
    hiddenimports += _ret[2]


# ── Uvicorn: toàn bộ loader động ─────────────────────────────────────────────
# Uvicorn chọn implementation lúc runtime qua chuỗi tên module, PyInstaller
# không lần theo được nên phải liệt kê tay.
hiddenimports += [
    'uvicorn.logging',
    'uvicorn.loops',
    'uvicorn.loops.auto',
    'uvicorn.loops.asyncio',
    'uvicorn.protocols',
    'uvicorn.protocols.http',
    'uvicorn.protocols.http.auto',
    'uvicorn.protocols.http.h11_impl',
    'uvicorn.protocols.websockets',
    'uvicorn.protocols.websockets.auto',
    'uvicorn.protocols.websockets.websockets_impl',
    'uvicorn.protocols.websockets.wsproto_impl',
    'uvicorn.lifespan',
    'uvicorn.lifespan.on',
    'uvicorn.lifespan.off',
]

# ── WebSocket ────────────────────────────────────────────────────────────────
# Cần cho /chat và /call/ws, và cho việc phát `event_reaction` của event engine.
# Thiếu nhóm này thì webhook HTTP vẫn bắn được nhưng client KHÔNG nhận được
# realtime event — lỗi rất dễ chẩn đoán nhầm.
hiddenimports += [
    'websockets',
    'websockets.legacy',
    'websockets.legacy.server',
    'wsproto',            # fallback nếu websockets không nạp được
]

# ── httpx & phụ thuộc ────────────────────────────────────────────────────────
# Dùng cho: webhook dispatch (event_engine._send_webhook_http_post) và
# peer-sync polling (app.py._sync_with_one_peer).
# anyio._backends._asyncio được nạp ĐỘNG theo tên chuỗi → bắt buộc khai báo.
hiddenimports += [
    'httpx',
    'httpcore',
    'h11',
    'anyio',
    'anyio._backends',
    'anyio._backends._asyncio',
    'sniffio',
    'idna',
]

# ── Module nội bộ ────────────────────────────────────────────────────────────
# Về mặt kỹ thuật đều được import tĩnh từ app.py nên PyInstaller tự tìm ra.
# Liệt kê ở đây để nếu sau này ai đó chuyển sang import động thì bản build
# không vỡ, và để đọc spec là biết ngay server gồm những gì.
hiddenimports += [
    'database',
    'db_init',
    'dependencies',
    'server_config',
    'server_discovery',
    'event_engine',
    'repository.interface',
    'repository.sqlite_repo',
    'routers.sync',
    'routers.peer_sync',
    'routers.devices',
    'routers.messages',
    'routers.notifications',
    'routers.attachments',
    'routers.call',
    'routers.webhooks',
    'routers.admin',
]


a = Analysis(
    ['app.py'],
    pathex=[],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    # Server không dùng GUI — loại bỏ để giảm dung lượng bản build.
    excludes=['tkinter', 'matplotlib', 'PIL', 'pytest'],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='izii_server',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    # UPX làm hỏng một số .pyd biên dịch sẵn — loại trừ để tránh lỗi nạp
    # module khó truy vết lúc runtime.
    upx_exclude=['vcruntime140.dll', 'python3*.dll', '_zeroconf*.pyd'],
    name='izii_server',
)
