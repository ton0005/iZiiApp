"""
sync_server.py — Delta Sync Module (Server-to-Server)
=======================================================

Module này bổ sung cơ chế đồng bộ dữ liệu (delta sync) giữa các server
trong kiến trúc multi-server của iZiiApp / Costa Mushroom.

Nguyên tắc:
- Mỗi bản ghi có: id (UUID), updated_at, version, origin_server_id
- Server A định kỳ (hoặc theo trigger) hỏi Server B: "cho tôi các bản ghi
  đã thay đổi kể từ last_sync_timestamp"
- Conflict resolution: Last-Write-Wins theo mặc định, có rule riêng cho
  Room (unique room_number) và Job (giữ cả 2 nếu tạo mới đồng thời)

Yêu cầu cài đặt:
    pip install fastapi uvicorn httpx pydantic --break-system-packages
"""

from __future__ import annotations

import asyncio
import logging
import uuid
from datetime import datetime, timezone
from enum import Enum
from typing import Optional

import httpx
from fastapi import APIRouter, FastAPI, HTTPException
from pydantic import BaseModel, Field

logger = logging.getLogger("delta_sync")
logging.basicConfig(level=logging.INFO)

# --------------------------------------------------------------------------
# 1. Cấu hình server hiện tại (mỗi server có 1 config riêng, load từ .env)
# --------------------------------------------------------------------------

class ServerConfig(BaseModel):
    server_id: str          # vd "server-m1", "server-m2", "server-cr"
    zone: str                # vd "M1", "M2", "CR"
    host: str
    port: int = 8080
    peers: list[str] = Field(default_factory=list)   # ["http://192.168.1.11:8080", ...]
    sync_interval_seconds: int = 45


CONFIG = ServerConfig(
    server_id="server-m1",
    zone="M1",
    host="192.168.1.10",
    port=8080,
    peers=[
        "http://192.168.1.11:8080",  # Server-M2
        "http://192.168.1.12:8080",  # Server-CR
    ],
    sync_interval_seconds=45,
)

# --------------------------------------------------------------------------
# 2. Model dữ liệu dùng chung cho sync (áp dụng cho Job, Room, Employee...)
#    Đây là "envelope" bọc quanh record thật để mang metadata sync.
# --------------------------------------------------------------------------

class EntityType(str, Enum):
    JOB = "job"
    ROOM = "room"
    EMPLOYEE = "employee"


class SyncEnvelope(BaseModel):
    """Bọc quanh 1 bản ghi bất kỳ cần đồng bộ giữa các server."""
    id: str                              # UUID, KHÔNG dùng auto-increment
    entity_type: EntityType
    payload: dict                        # nội dung thật của record (Job/Room/Employee)
    updated_at: datetime
    version: int = 1
    origin_server_id: str
    deleted: bool = False                # soft-delete, không xoá cứng khi sync


class SyncRequest(BaseModel):
    requester_server_id: str
    since: datetime                      # "cho tôi các thay đổi từ mốc này"
    entity_types: Optional[list[EntityType]] = None   # None = tất cả


class SyncResponse(BaseModel):
    server_id: str
    server_time: datetime
    changes: list[SyncEnvelope]


class ConflictLog(BaseModel):
    entity_id: str
    entity_type: EntityType
    local_version: int
    incoming_version: int
    resolution: str    # "kept_local" | "applied_incoming" | "kept_both" | "rejected"
    detail: str = ""


# --------------------------------------------------------------------------
# 3. Repository giả lập (thực tế sẽ query Drift/SQLite qua adapter Python)
#    Ở đây dùng in-memory dict để minh hoạ rõ logic, thay bằng DB thật khi
#    tích hợp — interface giữ nguyên.
# --------------------------------------------------------------------------

class LocalStore:
    """Đại diện cho lớp truy cập dữ liệu local (SQLite/Drift) của server này."""

    def __init__(self):
        self._data: dict[str, SyncEnvelope] = {}
        # Index riêng để check unique constraint (vd room_number theo zone)
        self._room_number_index: dict[tuple[str, str], str] = {}  # (zone, room_number) -> entity_id

    def get(self, entity_id: str) -> Optional[SyncEnvelope]:
        return self._data.get(entity_id)

    def get_changes_since(
        self, since: datetime, entity_types: Optional[list[EntityType]] = None
    ) -> list[SyncEnvelope]:
        result = []
        for env in self._data.values():
            if env.updated_at <= since:
                continue
            if entity_types and env.entity_type not in entity_types:
                continue
            result.append(env)
        return result

    def upsert_local(self, env: SyncEnvelope) -> None:
        """Ghi bản ghi được tạo/sửa TẠI server này (không phải từ sync)."""
        env.origin_server_id = CONFIG.server_id
        env.updated_at = datetime.now(timezone.utc)
        existing = self._data.get(env.id)
        env.version = (existing.version + 1) if existing else 1
        self._data[env.id] = env

    def apply_incoming(self, env: SyncEnvelope) -> ConflictLog:
        """
        Áp dụng 1 bản ghi đến từ server khác, xử lý conflict theo entity_type.
        Trả về ConflictLog để ghi audit / hiển thị cho Manager nếu cần.
        """
        existing = self._data.get(env.id)

        # --- Case: Room — unique room_number theo zone, KHÔNG dùng LWW ---
        if env.entity_type == EntityType.ROOM:
            return self._apply_room(env, existing)

        # --- Case: Job — nếu là 2 job MỚI tạo gần như đồng thời cho cùng
        #     room (id khác nhau) thì đây không phải conflict thật, mỗi cái
        #     là 1 envelope riêng nên tự động "giữ cả 2" (không cần xử lý gì
        #     đặc biệt ở tầng envelope — chỉ cảnh báo ở tầng business logic
        #     nếu trùng loại job + cùng khung giờ, xem hàm _warn_duplicate_job)
        if env.entity_type == EntityType.JOB:
            return self._apply_default_lww(env, existing, warn_duplicate=True)

        # --- Case còn lại (Employee, ...): Last-Write-Wins mặc định ---
        return self._apply_default_lww(env, existing)

    # ---- Chiến lược mặc định: Last-Write-Wins theo version, tie-break bằng updated_at ----
    def _apply_default_lww(
        self, incoming: SyncEnvelope, existing: Optional[SyncEnvelope], warn_duplicate: bool = False
    ) -> ConflictLog:
        if existing is None:
            self._data[incoming.id] = incoming
            if warn_duplicate:
                self._warn_duplicate_job(incoming)
            return ConflictLog(
                entity_id=incoming.id, entity_type=incoming.entity_type,
                local_version=0, incoming_version=incoming.version,
                resolution="applied_incoming", detail="Record mới, chưa tồn tại local.",
            )

        if incoming.version > existing.version or (
            incoming.version == existing.version and incoming.updated_at > existing.updated_at
        ):
            self._data[incoming.id] = incoming
            return ConflictLog(
                entity_id=incoming.id, entity_type=incoming.entity_type,
                local_version=existing.version, incoming_version=incoming.version,
                resolution="applied_incoming", detail="Incoming mới hơn (version/timestamp cao hơn).",
            )

        return ConflictLog(
            entity_id=incoming.id, entity_type=incoming.entity_type,
            local_version=existing.version, incoming_version=incoming.version,
            resolution="kept_local", detail="Local đã mới hơn hoặc bằng, bỏ qua incoming.",
        )

    # ---- Chiến lược riêng cho Room: chặn cứng nếu trùng room_number cùng zone ----
    def _apply_room(self, incoming: SyncEnvelope, existing: Optional[SyncEnvelope]) -> ConflictLog:
        room_number = incoming.payload.get("room_number")
        zone = incoming.payload.get("zone")
        key = (zone, room_number)

        # Nếu record này (theo id) đã tồn tại local -> coi như update bình thường (LWW)
        if existing is not None:
            return self._apply_default_lww(incoming, existing)

        # Record mới -> kiểm tra unique constraint theo (zone, room_number)
        conflicting_id = self._room_number_index.get(key)
        if conflicting_id and conflicting_id != incoming.id:
            logger.warning(
                "Reject Room sync: room_number %s trùng trong zone %s (đã có id=%s, incoming id=%s)",
                room_number, zone, conflicting_id, incoming.id,
            )
            return ConflictLog(
                entity_id=incoming.id, entity_type=EntityType.ROOM,
                local_version=0, incoming_version=incoming.version,
                resolution="rejected",
                detail=f"Room {room_number} trong zone {zone} đã tồn tại (id={conflicting_id}). "
                       f"Cần Manager xem lại thủ công.",
            )

        self._data[incoming.id] = incoming
        self._room_number_index[key] = incoming.id
        return ConflictLog(
            entity_id=incoming.id, entity_type=EntityType.ROOM,
            local_version=0, incoming_version=incoming.version,
            resolution="applied_incoming", detail="Room mới, không trùng room_number.",
        )

    def _warn_duplicate_job(self, incoming: SyncEnvelope) -> None:
        """
        Cảnh báo (không chặn) nếu có Job cùng loại, cùng room, cùng khung giờ
        được tạo bởi 2 server khác nhau gần như đồng thời — Manager cần biết
        để tránh double-work, nhưng KHÔNG tự động xoá bớt.
        """
        room_id = incoming.payload.get("room_id")
        job_type = incoming.payload.get("job_type")
        scheduled_date = incoming.payload.get("scheduled_date")

        for env in self._data.values():
            if env.id == incoming.id or env.entity_type != EntityType.JOB:
                continue
            p = env.payload
            if (
                p.get("room_id") == room_id
                and p.get("job_type") == job_type
                and p.get("scheduled_date") == scheduled_date
            ):
                logger.warning(
                    "Có thể trùng Job: room=%s type=%s date=%s (id cũ=%s, id mới=%s). "
                    "Không tự xoá, cần Manager xác nhận.",
                    room_id, job_type, scheduled_date, env.id, incoming.id,
                )


STORE = LocalStore()
sync_router = APIRouter(prefix="/sync", tags=["sync"])


# --------------------------------------------------------------------------
# 4. API endpoint: server khác gọi vào đây để lấy delta / đẩy delta
# --------------------------------------------------------------------------

@sync_router.post("/pull", response_model=SyncResponse)
async def handle_pull(req: SyncRequest) -> SyncResponse:
    """
    Server khác gọi endpoint này để HỎI delta của server hiện tại.
    Ví dụ: Server-M2 gọi Server-M1: "cho tôi thay đổi từ lúc X".
    """
    changes = STORE.get_changes_since(req.since, req.entity_types)
    logger.info(
        "Pull request từ %s (since=%s): trả về %d thay đổi",
        req.requester_server_id, req.since, len(changes),
    )
    return SyncResponse(
        server_id=CONFIG.server_id,
        server_time=datetime.now(timezone.utc),
        changes=changes,
    )


@sync_router.post("/push", response_model=list[ConflictLog])
async def handle_push(changes: list[SyncEnvelope]) -> list[ConflictLog]:
    """
    Server khác chủ động ĐẨY thay đổi sang server hiện tại (dùng khi
    chuyển sang event-based sync ở Phase 4, thay vì chỉ pull định kỳ).
    """
    logs = []
    for env in changes:
        if env.origin_server_id == CONFIG.server_id:
            # Tránh tự sync ngược lại chính mình (loop)
            continue
        log = STORE.apply_incoming(env)
        logs.append(log)
    return logs


@sync_router.get("/health")
async def health_check() -> dict:
    return {
        "server_id": CONFIG.server_id,
        "zone": CONFIG.zone,
        "status": "ok",
        "record_count": len(STORE._data),
        "server_time": datetime.now(timezone.utc).isoformat(),
    }


# --------------------------------------------------------------------------
# 5. Background task: định kỳ PULL từ các peer server (polling delta-sync)
# --------------------------------------------------------------------------

class PeerSyncState:
    """Lưu last_sync_timestamp riêng cho từng peer, để mỗi lần chỉ hỏi
    'thay đổi từ mốc trước', tránh kéo lại toàn bộ dữ liệu mỗi lần."""

    def __init__(self):
        self._last_sync: dict[str, datetime] = {}

    def get(self, peer_url: str) -> datetime:
        return self._last_sync.get(peer_url, datetime.fromtimestamp(0, tz=timezone.utc))

    def set(self, peer_url: str, ts: datetime) -> None:
        self._last_sync[peer_url] = ts


PEER_STATE = PeerSyncState()


async def sync_with_peer(client: httpx.AsyncClient, peer_url: str) -> None:
    since = PEER_STATE.get(peer_url)
    try:
        resp = await client.post(
            f"{peer_url}/sync/pull",
            json=SyncRequest(requester_server_id=CONFIG.server_id, since=since).model_dump(mode="json"),
            timeout=10.0,
        )
        resp.raise_for_status()
        data = SyncResponse(**resp.json())
    except httpx.HTTPError as e:
        logger.warning("Không thể sync với peer %s: %s (server có thể đang offline)", peer_url, e)
        return

    conflict_count = 0
    for env in data.changes:
        if env.origin_server_id == CONFIG.server_id:
            continue  # tránh sync ngược lại chính mình
        log = STORE.apply_incoming(env)
        if log.resolution in ("rejected", "kept_local"):
            conflict_count += 1

    PEER_STATE.set(peer_url, data.server_time)
    logger.info(
        "Sync với %s hoàn tất: %d bản ghi nhận, %d conflict cần chú ý",
        peer_url, len(data.changes), conflict_count,
    )


async def periodic_sync_loop() -> None:
    """Chạy nền: cứ mỗi `sync_interval_seconds` lại pull từ tất cả peers."""
    async with httpx.AsyncClient() as client:
        while True:
            await asyncio.gather(
                *(sync_with_peer(client, peer) for peer in CONFIG.peers),
                return_exceptions=True,
            )
            await asyncio.sleep(CONFIG.sync_interval_seconds)


# --------------------------------------------------------------------------
# 6. Khởi tạo FastAPI app, đăng ký router + background task
# --------------------------------------------------------------------------

def create_app() -> FastAPI:
    app = FastAPI(title=f"iZiiApp Sync Server — {CONFIG.zone}")
    app.include_router(sync_router)

    @app.on_event("startup")
    async def on_startup():
        logger.info("Server %s (zone=%s) khởi động, bắt đầu vòng lặp sync nền...", CONFIG.server_id, CONFIG.zone)
        asyncio.create_task(periodic_sync_loop())

    return app


app = create_app()


# --------------------------------------------------------------------------
# 7. Ví dụ: khi Manager tạo Job mới ở server này, gọi upsert_local() rồi
#    dữ liệu sẽ tự lan sang các server khác ở lần polling tiếp theo (hoặc
#    có thể chủ động push ngay bằng cách gọi handle_push tới các peer).
# --------------------------------------------------------------------------

def example_create_job(room_id: str, job_type: str, scheduled_date: str) -> SyncEnvelope:
    env = SyncEnvelope(
        id=str(uuid.uuid4()),
        entity_type=EntityType.JOB,
        payload={
            "room_id": room_id,
            "job_type": job_type,
            "scheduled_date": scheduled_date,
            "status": "pending",
        },
        updated_at=datetime.now(timezone.utc),
        origin_server_id=CONFIG.server_id,
    )
    STORE.upsert_local(env)
    logger.info("Đã tạo Job mới local: %s", env.id)
    return env


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=CONFIG.host, port=CONFIG.port)
