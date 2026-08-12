# server/routers/call.py
"""
WebRTC Voice & Video Call Signaling Router.
Handles STUN/TURN configuration and Real-time WebSocket SDP/ICE candidate relay.
"""
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, HTTPException
from pydantic import BaseModel
from typing import Dict, List, Optional
import json
import asyncio
from datetime import datetime

router = APIRouter(prefix="/call", tags=["WebRTC Call Engine"])

# Active WebSockets map: client_id -> WebSocket
connected_clients: Dict[str, WebSocket] = {}

# Đếm ICE candidate mỗi client đã gửi, chỉ để ghi log thưa. ICE candidate có
# hàng chục gói mỗi cuộc gọi — in hết thì log không đọc được nữa.
_ice_counts: Dict[str, int] = {}

class CallInviteModel(BaseModel):
    call_id: str
    caller_id: str
    caller_name: str
    callee_id: str
    call_type: str  # 'audio' or 'video'
    room_id: Optional[str] = None


@router.get("/stun-turn-config")
async def get_stun_turn_config():
    """
    Returns public STUN and TURN server credentials for NAT traversal.
    """
    return {
        "iceServers": [
            {"urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]},
            {"urls": ["stun:stun2.l.google.com:19302", "stun:stun3.l.google.com:19302"]},
            {"urls": ["stun:stun4.l.google.com:19302"]},
        ]
    }


@router.post("/invite")
async def invite_call(invite: CallInviteModel):
    """
    HTTP trigger to initiate a call invite if client isn't yet connected on call WebSocket.
    """
    target_ws = connected_clients.get(invite.callee_id)
    payload = {
        "event": "call_invite",
        "data": invite.model_dump(),
        "timestamp": datetime.now().isoformat()
    }
    
    if target_ws:
        try:
            await target_ws.send_text(json.dumps(payload))
            return {"status": "success", "delivered": True}
        except Exception as e:
            print(f"⚠️ [CALL] Failed sending invite to {invite.callee_id}: {e}")

    return {"status": "queued", "delivered": False}


@router.websocket("/ws/{client_id}")
async def call_signaling_ws(websocket: WebSocket, client_id: str):
    """
    Dedicated WebRTC Signaling WebSocket channel for SDP Offers, Answers, and ICE Candidates.
    """
    await websocket.accept()
    connected_clients[client_id] = websocket
    print(f"📞 [CALL-WS] Client '{client_id}' connected to Call Signaling. Total call clients: {len(connected_clients)}")

    try:
        while True:
            raw_data = await websocket.receive_text()
            try:
                msg = json.loads(raw_data)
                event_type = msg.get("event")
                target_id = msg.get("target_id")
                data = msg.get("data", {})
                
                # Tag sender ID
                data["sender_id"] = client_id
                # Nhét target_id vào CẢ hai chỗ. Kênh /chat là broadcast nên
                # máy nhận phải tự lọc "gói này có phải cho mình không" — thiếu
                # trường này thì máy thứ ba cũng đổ chuông và nhận luôn SDP/ICE
                # của cuộc gọi không liên quan.
                if target_id:
                    data["target_id"] = target_id

                payload = json.dumps({
                    "event": event_type,
                    "target_id": target_id,
                    "data": data,
                    "timestamp": datetime.now().isoformat()
                })

                # Ghi lại tiến độ thương lượng. Không có dòng này thì log server
                # hoàn toàn im lặng về SDP/ICE và không thể biết cuộc gọi hỏng ở
                # bước nào — mời, nghe máy, trao đổi SDP, hay thu thập ICE.
                if event_type in ("call_invite", "call_accept", "call_reject",
                                  "call_end", "sdp_offer", "sdp_answer"):
                    print(
                        f"📞 [SIGNAL] {client_id} → {target_id or '(broadcast)'} : {event_type}"
                    )
                elif event_type == "ice_candidate":
                    _ice_counts[client_id] = _ice_counts.get(client_id, 0) + 1
                    if _ice_counts[client_id] in (1, 5, 10, 25, 50):
                        print(
                            f"🧊 [SIGNAL] {client_id} đã gửi {_ice_counts[client_id]} "
                            f"ICE candidate tới {target_id or '(broadcast)'}"
                        )

                if target_id and target_id in connected_clients:
                    await connected_clients[target_id].send_text(payload)
                    continue

                # Định tuyến trực tiếp trượt. Nếu CÓ client đang kết nối mà
                # target_id lại không khớp id nào, gần như chắc chắn hai bên
                # đang dùng hai hệ danh tính khác nhau (device_id vs user_id) —
                # lỗi im lặng vì đường quảng bá vẫn hoạt động, chỉ chậm và rò.
                if target_id and connected_clients:
                    print(
                        f"⚠️  [SIGNAL] '{target_id}' KHÔNG có trên /call/ws. "
                        f"Đang kết nối: {sorted(connected_clients)}. "
                        f"Nếu hai danh sách khác hệ định danh thì đó là lỗi cấu hình client."
                    )

                # Người nhận chưa mở /call/ws — phát dự phòng qua kênh /chat.
                # Máy nào cũng nhận được gói này nhưng chỉ máy đúng target_id
                # mới xử lý.
                #
                # CỐ Ý KHÔNG gửi vòng cho mọi client /call/ws còn lại: đó là
                # phát tán dữ liệu cuộc gọi cho người ngoài cuộc, và cũng không
                # giúp gì vì máy đúng người đã được thử ở nhánh trên.
                ws_state = getattr(getattr(websocket, "app", None), "state", None)
                ws_manager = getattr(ws_state, "ws_manager", None)
                if ws_manager:
                    await ws_manager.broadcast(payload, exclude=None)
                else:
                    print(
                        f"⚠️ [CALL-WS] '{target_id}' không online trên /call/ws "
                        f"và không có ws_manager để phát dự phòng — gói {event_type} bị rơi."
                    )
            except json.JSONDecodeError:
                pass
            except Exception as e:
                print(f"⚠️ [CALL-WS] Error handling message from {client_id}: {e}")

    except WebSocketDisconnect:
        print(f"📞 [CALL-WS] Client '{client_id}' disconnected.")
    finally:
        connected_clients.pop(client_id, None)
        _ice_counts.pop(client_id, None)
