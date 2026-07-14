# Hướng dẫn Rebuild iZiiApp Standalone Server (iziiapp_server.exe)

Tài liệu này hướng dẫn cách đóng gói (build) ứng dụng FastAPI Backend của iZiiApp thành file thực thi độc lập (`iziiapp_server.exe`) trên Windows bằng PyInstaller sau khi đã cấu hình kiến trúc Modular (v2.0).

Kill port 8080:
The server process has been successfully killed and port 8080 is now free. Let's verify that the port is free: Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue
---

## 1. Yêu cầu hệ thống & Môi trường

Trước khi tiến hành build, đảm bảo máy tính đã cài đặt:

- **Python 3.11** hoặc **Python 3.14+**
- Các thư viện Python cần thiết (bao gồm thư viện `websockets` hỗ trợ WebSocket Chat):

```bash
# Cài đặt FastAPI và Uvicorn
pip install fastapi uvicorn

# Cài đặt thư viện Websocket (Quan trọng: Tránh lỗi 404 /chat trên WebSocket)
pip install websockets

# Cài đặt PyInstaller
pip install pyinstaller
```

---

## 2. Các file mới và Cấu hình PyInstaller Spec

Do server đã được chuyển từ file đơn lẻ (`app.py`) sang cấu trúc thư mục modular, cấu hình spec của PyInstaller cần nhận diện các module mới:
- `database.py`: Quản lý SQLite connection & PRAGMAs.
- `dependencies.py`: FastAPI Dependency Injection.
- Thư mục `repository/`: Các interfaces & SQLite repositories.
- Thư mục `routers/`: Chứa api endpoints riêng lẻ.

Đường dẫn tìm kiếm (`pathex`) trong file cấu hình `iziiapp_server.spec` đã được cập nhật thành `pathex=['server']` để PyInstaller tự động phân tích và import các thành phần trên.

### File cấu hình `iziiapp_server.spec` hiện tại:

```python
# -*- mode: python ; coding: utf-8 -*-

a = Analysis(
    ['server\\app.py'],
    pathex=['server'],  # Thư mục chứa các module con của server
    binaries=[],
    datas=[],
    hiddenimports=[
        'uvicorn.logging', 
        'uvicorn.loops', 
        'uvicorn.loops.auto', 
        'uvicorn.protocols', 
        'uvicorn.protocols.http', 
        'uvicorn.protocols.http.auto', 
        'uvicorn.protocols.websockets', 
        'uvicorn.protocols.websockets.auto', 
        'uvicorn.lifespan', 
        'uvicorn.lifespan.on', 
        'uvicorn.lifespan.off', 
        'websockets', 
        'websockets.legacy', 
        'websockets.legacy.server'
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='iziiapp_server',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
```

---

## 3. Các bước tiến hành Rebuild

1. Mở PowerShell hoặc Command Prompt tại thư mục gốc của dự án (`izii_app`):
   ```powershell
   cd C:\Users\CHANH\OneDrive\Documents\Downloads\Compressed\izii_app
   ```

2. Chạy lệnh PyInstaller với cờ `--clean` để xóa bộ nhớ cache cũ và build lại:
   ```bash
   pyinstaller --clean iziiapp_server.spec
   ```

3. Quá trình build sẽ tạo ra:
   - Thư mục `build/` chứa các file log trung gian.
   - Thư mục `dist/` chứa sản phẩm đầu ra: `dist/iziiapp_server.exe` (~36MB).

---

## 4. Xác minh và Kiểm tra sau khi build

Sau khi quá trình build hoàn tất, kiểm tra file thực thi trong thư mục `dist`:

1. Chạy thử server:
   ```powershell
   cd dist
   .\iziiapp_server.exe
   ```

2. Xác nhận log xuất hiện thông báo:
   - `🚀 Starting iZiiApp Standalone Server v2.0 in Bundled Mode...`
   - `✅ Database auto-initialized successfully...`
   - Không xuất hiện cảnh báo `No supported WebSocket library detected`.

3. Kiểm tra các cổng kết nối bằng cách truy cập:
   - Tài liệu API: [http://localhost:8080/docs](http://localhost:8080/docs)
   - Trạng thái Sync: [http://localhost:8080/sync/status](http://localhost:8080/sync/status)
