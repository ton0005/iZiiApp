# server/routers/attachments.py
import os
import hashlib
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends

from database import get_stable_data_dir
from security_auth import optional_device

# Upload yêu cầu danh tính thiết bị (optional_device): khi
# IZIIAPP_REQUIRE_DEVICE_TOKEN=1 thì bắt buộc có X-iZii-Device-Token, nếu không
# vẫn ghi audit được ai upload. Không để endpoint này mở hoàn toàn nữa.
router = APIRouter(prefix="/api/v1/attachments", tags=["Attachments"],
                   dependencies=[Depends(optional_device)])

# Giới hạn kích thước: nạp cả file vào RAM nên phải chặn để tránh DoS bộ nhớ/đĩa.
MAX_UPLOAD_BYTES = 25 * 1024 * 1024  # 25 MB

# Chỉ cho các loại tệp đính kèm hợp lệ. KHÔNG cho .html/.svg/.xml... vì tệp được
# serve tĩnh cùng origin tại /uploads → tránh stored XSS. Không cho tệp thực thi.
ALLOWED_EXTENSIONS = {
    ".jpg", ".jpeg", ".png", ".gif", ".webp", ".heic",
    ".pdf", ".txt", ".csv",
    ".doc", ".docx", ".xls", ".xlsx",
    ".mp4", ".mov", ".m4a", ".aac", ".mp3", ".wav",
}

# Phần mở rộng thực thi/nguy hiểm — chặn tuyệt đối dù có lọt allowlist vì lý do nào.
_FORBIDDEN_EXTENSIONS = {
    ".html", ".htm", ".svg", ".xml", ".xhtml", ".js", ".mjs",
    ".php", ".phtml", ".py", ".pyc", ".sh", ".bat", ".cmd", ".ps1",
    ".exe", ".dll", ".so", ".jar", ".com", ".scr", ".vbs", ".hta",
}


@router.post("/upload")
async def upload_attachment(file: UploadFile = File(...)):
    try:
        uploads_dir = os.path.join(get_stable_data_dir(), "uploads")
        os.makedirs(uploads_dir, exist_ok=True)

        # Chuẩn hoá & kiểm phần mở rộng TRƯỚC khi đọc nội dung.
        original_name = file.filename or "attachment"
        # Chỉ lấy phần tên cuối, loại mọi thành phần đường dẫn (chống path traversal
        # trong tên file do client đặt).
        base_name = os.path.basename(original_name.replace("\\", "/"))
        file_ext = os.path.splitext(base_name)[1].lower()

        if file_ext in _FORBIDDEN_EXTENSIONS:
            raise HTTPException(status_code=415, detail=f"Loại tệp bị cấm: {file_ext}")
        if file_ext not in ALLOWED_EXTENSIONS:
            raise HTTPException(
                status_code=415,
                detail=f"Loại tệp không được hỗ trợ: {file_ext or '(không có đuôi)'}",
            )

        # Đọc theo chunk, dừng ngay khi vượt giới hạn — không nạp vô hạn vào RAM.
        hasher = hashlib.sha256()
        total = 0
        chunks = []
        while True:
            chunk = await file.read(1024 * 1024)  # 1 MB/lần
            if not chunk:
                break
            total += len(chunk)
            if total > MAX_UPLOAD_BYTES:
                raise HTTPException(
                    status_code=413,
                    detail=f"Tệp vượt giới hạn {MAX_UPLOAD_BYTES // (1024 * 1024)} MB",
                )
            hasher.update(chunk)
            chunks.append(chunk)

        if total == 0:
            raise HTTPException(status_code=400, detail="Tệp rỗng")

        file_hash = hasher.hexdigest()
        # Tên lưu = hash (hex, an toàn) + đuôi đã nằm trong allowlist.
        unique_filename = f"{file_hash}{file_ext}"
        file_path = os.path.join(uploads_dir, unique_filename)

        # Chốt chặn cuối: đảm bảo đường dẫn thực vẫn nằm trong uploads_dir.
        real_uploads = os.path.realpath(uploads_dir)
        real_target = os.path.realpath(file_path)
        if os.path.commonpath([real_uploads, real_target]) != real_uploads:
            raise HTTPException(status_code=400, detail="Đường dẫn tệp không hợp lệ")

        if not os.path.exists(file_path):
            with open(file_path, "wb") as buffer:
                for chunk in chunks:
                    buffer.write(chunk)

        print(f"📥 [ATTACHMENT] Đã nhận tệp: {base_name} ({total} bytes) -> {unique_filename}")
        return {
            "status": "success",
            "filename": base_name,
            "unique_name": unique_filename,
            "url": f"/uploads/{unique_filename}",
            "size": total,
        }
    except HTTPException:
        raise  # giữ nguyên mã lỗi 4xx đã chọn, không bọc thành 500
    except Exception as e:
        print(f"❌ [ATTACHMENT] Lỗi tải lên tệp đính kèm: {e}")
        raise HTTPException(status_code=500, detail="Upload failed")


@router.get("/verify/{file_hash}")
async def verify_attachment_hash(file_hash: str):
    """Kiểm tra xem file đã tồn tại trên máy chủ hay chưa bằng SHA-256 hash để tránh upload trùng lặp."""
    uploads_dir = os.path.join(get_stable_data_dir(), "uploads")
    if not os.path.exists(uploads_dir):
        return {"exists": False}

    for fname in os.listdir(uploads_dir):
        if fname.startswith(file_hash):
            fpath = os.path.join(uploads_dir, fname)
            return {
                "exists": True,
                "filename": fname,
                "url": f"/uploads/{fname}",
                "size": os.path.getsize(fpath)
            }
    return {"exists": False}


@router.post("/chunk")
async def upload_attachment_chunk(
    file_hash: str = File(...),
    chunk_index: int = File(...),
    total_chunks: int = File(...),
    file_ext: str = File(...),
    chunk: UploadFile = File(...)
):
    """Tải lên tệp đính kèm theo từng chunk nhỏ để hỗ trợ resume."""
    uploads_dir = os.path.join(get_stable_data_dir(), "uploads")
    temp_dir = os.path.join(uploads_dir, "_chunks", file_hash)
    os.makedirs(temp_dir, exist_ok=True)

    chunk_path = os.path.join(temp_dir, f"part_{chunk_index}")
    chunk_bytes = await chunk.read()
    with open(chunk_path, "wb") as f:
        f.write(chunk_bytes)

    # Kiểm tra xem đủ tất cả chunks chưa
    parts = [os.path.join(temp_dir, f"part_{i}") for i in range(total_chunks)]
    if all(os.path.exists(p) for p in parts):
        target_fname = f"{file_hash}{file_ext}"
        final_path = os.path.join(uploads_dir, target_fname)
        with open(final_path, "wb") as outfile:
            for p in parts:
                with open(p, "rb") as infile:
                    outfile.write(infile.read())
                try:
                    os.remove(p)
                except Exception:
                    pass
        try:
            os.rmdir(temp_dir)
        except Exception:
            pass
        return {
            "status": "completed",
            "url": f"/uploads/{target_fname}",
            "size": os.path.getsize(final_path)
        }

    return {
        "status": "chunk_received",
        "chunk_index": chunk_index,
        "total_chunks": total_chunks
    }
