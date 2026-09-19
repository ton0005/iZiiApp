# server/routers/attachments.py
import sys
import os
import shutil
import uuid
import hashlib
from fastapi import APIRouter, UploadFile, File, HTTPException

router = APIRouter(prefix="/api/v1/attachments", tags=["Attachments"])

from database import get_stable_data_dir

@router.post("/upload")
async def upload_attachment(file: UploadFile = File(...)):
    try:
        uploads_dir = os.path.join(get_stable_data_dir(), "uploads")
        os.makedirs(uploads_dir, exist_ok=True)
        
        # Read file contents and compute SHA-256 for content deduplication
        contents = await file.read()
        file_hash = hashlib.sha256(contents).hexdigest()
        
        original_name = file.filename or "attachment"
        file_ext = os.path.splitext(original_name)[1].lower()
        unique_filename = f"{file_hash}{file_ext}"
        
        file_path = os.path.join(uploads_dir, unique_filename)
        
        # Only write if it does not already exist (avoids duplicate disk writes)
        if not os.path.exists(file_path):
            with open(file_path, "wb") as buffer:
                buffer.write(contents)
            
        file_size = len(contents)
        
        # Return attachment info. URL is relative, client can prepend the server base URL.
        return {
            "status": "success",
            "filename": original_name,
            "unique_name": unique_filename,
            "url": f"/uploads/{unique_filename}",
            "size": file_size
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")
