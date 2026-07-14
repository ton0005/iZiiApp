# server/routers/devices.py
"""
Track 2 — Device Identity Router.

Handles device registration, heartbeats, and key lookups:
- POST /api/v1/devices/register   — Register a new device
- POST /api/v1/devices/heartbeat  — Update device last_seen_at
- GET  /api/v1/devices/online     — List online/idle devices
- GET  /api/v1/devices/{id}/key   — Lookup device public key
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

from dependencies import get_device_repo
from repository.interface import IDeviceRepository

router = APIRouter(prefix="/api/v1/devices", tags=["Device Identity"])


class DeviceRegister(BaseModel):
    device_id: str
    user_id: str
    public_key: Optional[str] = None
    public_key_base64: Optional[str] = None
    signing_public_key: Optional[str] = None
    signing_public_key_base64: Optional[str] = None
    device_name: str
    platform: str
    push_token: Optional[str] = None


class DeviceHeartbeat(BaseModel):
    device_id: str


@router.post("/register")
async def device_register(body: DeviceRegister, 
                           repo: IDeviceRepository = Depends(get_device_repo)):
    now = datetime.now().isoformat()
    
    try:
        device = repo.register(body.model_dump(), now)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
    print(f"\n🔐 [DEVICE] Registered: {body.device_name} ({body.platform}) DID: {body.device_id[:16]}...")
    print(f"   👤 User: {body.user_id}")
    
    return {"status": "success", "message": "Device registered successfully", "device": device}


@router.post("/heartbeat")
async def device_heartbeat(body: DeviceHeartbeat,
                            repo: IDeviceRepository = Depends(get_device_repo)):
    now = datetime.now().isoformat()
    
    found = repo.heartbeat(body.device_id, now)
    if not found:
        raise HTTPException(status_code=404, detail="Device not found in registry")
    
    return {"status": "success", "message": "Heartbeat received"}


@router.get("/online")
async def devices_online(user_id: Optional[str] = None,
                          exclude_device_id: Optional[str] = None,
                          repo: IDeviceRepository = Depends(get_device_repo)):
    devices = repo.get_online(user_id, exclude_device_id)
    
    print(f"\n📡 [ONLINE] Queried online devices → {len(devices)} active")
    return {"devices": devices}


@router.get("/{device_id}/key")
async def device_key_lookup(device_id: str,
                             repo: IDeviceRepository = Depends(get_device_repo)):
    device = repo.get_key(device_id)
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")
    
    print(f"\n🔑 [KEY] Key lookup for device: {device['device_name']} DID: {device_id[:16]}...")
    return device
