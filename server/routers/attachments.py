# server/routers/attachments.py
import sys
import os
import shutil
import uuid
from fastapi import APIRouter, UploadFile, File, HTTPException

router = APIRouter(prefix="/api/v1/attachments", tags=["Attachments"])

from database import get_stable_data_dir

@router.post("/upload")
async def upload_attachment(file: UploadFile = File(...)):
    try:
        uploads_dir = os.path.join(get_stable_data_dir(), "uploads")
        os.makedirs(uploads_dir, exist_ok=True)
        
        # Generate a unique filename using UUID to prevent collisions
        original_name = file.filename or "attachment"
        file_ext = os.path.splitext(original_name)[1]
        unique_filename = f"{uuid.uuid4().hex}{file_ext}"
        
        file_path = os.path.join(uploads_dir, unique_filename)
        
        # Save file contents
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
            
        file_size = os.path.getsize(file_path)
        
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
