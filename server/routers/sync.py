# server/routers/sync.py
"""
Track 1 — Sync Engine Router.

Handles data synchronization between client devices and the server:
- POST /sync/push  — Client pushes local changes to server
- GET  /sync/pull  — Client pulls new changes from server  
- GET  /sync/status — Server sync status summary
"""
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
import json
import asyncio

from dependencies import get_sync_repo
from repository.interface import ISyncRepository
from server_config import CONFIG

router = APIRouter(prefix="/sync", tags=["Sync Engine"])


class MutationModel(BaseModel):
    id: str
    client_id: Optional[str] = None
    table: str
    operation: str
    data: dict


class PushPayload(BaseModel):
    mutations: List[MutationModel]


@router.post("/push")
async def sync_push(payload: PushPayload, request: Request, repo: ISyncRepository = Depends(get_sync_repo)):
    now = datetime.now().isoformat()
    
    print(f"\n{'='*50}")
    print(f"📥 [PUSH] Received {len(payload.mutations)} changes at {now}")
    print(f"{'='*50}")
    
    try:
        mutations_dicts = []
        for i, m in enumerate(payload.mutations):
            print(f"   [{i+1}] 🔹 Table: {m.table} | Operation: {m.operation}")
            for key, val in m.data.items():
                val_str = str(val)[:80]
                print(f"       - {key}: {val_str}")
            mutations_dicts.append(m.model_dump())
        
        count = repo.push_mutations(mutations_dicts, now, default_origin_server_id=CONFIG.server_id)
        
        # Broadcast sync trigger to all active WebSocket clients!
        ws_manager = getattr(request.app.state, "ws_manager", None)
        if ws_manager:
            tables = list(set(m.table for m in payload.mutations))
            event_data = {
                "event": "sync_trigger",
                "data": {
                    "tables": tables,
                    "timestamp": now
                }
            }
            # Broadcast asynchronously
            asyncio.create_task(ws_manager.broadcast(json.dumps(event_data), exclude=None))
            print(f"📡 [WS] Broadcasted sync_trigger for tables: {tables}")
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
    return {"status": "success", "message": f"Processed {count} mutations"}


@router.get("/pull")
async def sync_pull(since: Optional[str] = None, 
                    repo: ISyncRepository = Depends(get_sync_repo)):
    now = datetime.now().isoformat()
    
    print(f"\n📤 [PULL] The device is downloading new updates...")
    if since:
        print(f"   🕐 Filtered since: {since}")
    
    try:
        updates = repo.pull_mutations(since)
        print(f"   📦 Sending {len(updates)} records")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
    return {"updates": updates, "timestamp": now}


@router.get("/status")
async def sync_status(repo: ISyncRepository = Depends(get_sync_repo)):
    try:
        return repo.get_status()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
