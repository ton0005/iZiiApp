# server/modules/module_manager.py
"""
iZiiServer Module Manager (Phase 2 - P2.1, P2.2, P2.3, P2.4, P2.5, P2.6).

Responsibilities:
- Module discovery from server/modules/
- Topological dependency resolution (detects cycles and missing deps)
- Module lifecycle management (install, upgrade, enable, disable)
- Tenant-level module enablement (tenant_modules table)
- Model registry mapping: logical model_name -> physical table_name (Q2 aliasing)
- Client schema version compatibility checks (P2.6)
"""
from __future__ import annotations

import os
import sys
import json
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Dict, List, Optional, Set, Any

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from server_config import CONFIG

MODULES_DIR = os.path.abspath(os.path.dirname(__file__))


@dataclass
class ModuleManifest:
    name: str
    version: str
    display_name: Dict[str, str] = field(default_factory=dict)
    depends: List[str] = field(default_factory=list)
    owns_tables: List[str] = field(default_factory=list)
    models: List[Dict[str, Any]] = field(default_factory=list)
    extends: List[Dict[str, Any]] = field(default_factory=list)
    min_client_schema_version: int = 1
    enabled_by_default: bool = True
    path: str = ""


class ModuleManager:
    def __init__(self, modules_dir: str = MODULES_DIR):
        self.modules_dir = modules_dir
        self.manifests: Dict[str, ModuleManifest] = {}
        self.sorted_modules: List[str] = []
        self._table_to_module: Dict[str, str] = {}
        self.discover_modules()

    def discover_modules(self) -> Dict[str, ModuleManifest]:
        """Quét toàn bộ thư mục con trong modules_dir tìm manifest.json."""
        self.manifests = {}
        self._table_to_module = {}

        if not os.path.exists(self.modules_dir):
            return self.manifests

        for entry in os.scandir(self.modules_dir):
            if entry.is_dir():
                manifest_path = os.path.join(entry.path, "manifest.json")
                if os.path.exists(manifest_path):
                    try:
                        with open(manifest_path, "r", encoding="utf-8-sig") as f:
                            data = json.load(f)

                        name = data.get("name")
                        if not name:
                            continue

                        manifest = ModuleManifest(
                            name=name,
                            version=data.get("version", "1.0.0"),
                            display_name=data.get("display_name", {}),
                            depends=data.get("depends", []),
                            owns_tables=data.get("owns_tables", []),
                            models=data.get("models", []),
                            extends=data.get("extends", []),
                            min_client_schema_version=int(data.get("min_client_schema_version", 1)),
                            enabled_by_default=bool(data.get("enabled_by_default", True)),
                            path=entry.path,
                        )
                        self.manifests[name] = manifest

                        for tbl in manifest.owns_tables:
                            self._table_to_module[tbl] = name

                    except Exception as e:
                        print(f"⚠️  [MODULE] Không thể đọc manifest tại {manifest_path}: {e}")

        self.sorted_modules = self.resolve_dependencies()
        return self.manifests

    def resolve_dependencies(self) -> List[str]:
        """
        Sắp xếp thứ tự nạp module theo cây phụ thuộc (Topological Sort).
        Phát hiện chu trình phụ thuộc (circular dependency) hoặc thiếu module phụ thuộc.
        """
        in_degree: Dict[str, int] = {name: 0 for name in self.manifests}
        adj_list: Dict[str, List[str]] = {name: [] for name in self.manifests}

        # Xây dựng đồ thị phụ thuộc
        for name, manifest in self.manifests.items():
            for dep in manifest.depends:
                if dep not in self.manifests:
                    raise ValueError(
                        f"Module '{name}' phụ thuộc vào module '{dep}' nhưng '{dep}' không tồn tại."
                    )
                adj_list[dep].append(name)
                in_degree[name] += 1

        # Kahn's algorithm
        queue = [name for name, deg in in_degree.items() if deg == 0]
        sorted_order = []

        while queue:
            curr = queue.pop(0)
            sorted_order.append(curr)

            for neighbor in adj_list[curr]:
                in_degree[neighbor] -= 1
                if in_degree[neighbor] == 0:
                    queue.append(neighbor)

        if len(sorted_order) != len(self.manifests):
            remaining = [m for m, deg in in_degree.items() if deg > 0]
            raise ValueError(
                f"Phát hiện chu trình phụ thuộc vòng (circular dependency) giữa các modules: {remaining}"
            )

        return sorted_order

    def get_table_owner(self, table_name: str) -> Optional[str]:
        """Trả về tên module sở hữu bảng tương ứng."""
        return self._table_to_module.get(table_name)

    def is_client_compatible(self, module_name: str, client_schema_version: int) -> bool:
        """P2.6: Kiểm tra phiên bản client schema có đáp ứng min_client_schema_version của module không."""
        manifest = self.manifests.get(module_name)
        if not manifest:
            return True
        return client_schema_version >= manifest.min_client_schema_version

    # ── Database Operations (Postgres & SQLite) ──────────────────────────────

    def install_module(self, module_name: str, tenant_id: str = "default", settings: Optional[dict] = None) -> bool:
        """
        Cài đặt module cho một tenant:
        - Đăng ký vào bảng tenant_modules
        - Đăng ký các model vào model_registry (Q2)
        """
        manifest = self.manifests.get(module_name)
        if not manifest:
            raise ValueError(f"Module '{module_name}' không tồn tại trong hệ thống.")

        # Cài đặt các phụ thuộc trước
        for dep in manifest.depends:
            if not self.is_module_installed(dep, tenant_id):
                self.install_module(dep, tenant_id)

        now_iso = datetime.now(timezone.utc).isoformat()
        settings_str = json.dumps(settings or {})

        backend = CONFIG.db_backend
        if backend == "postgres":
            from db_postgres import pg_connection
            with pg_connection() as conn:
                # 1. Ghi vào tenant_modules
                conn.execute(
                    """
                    INSERT INTO tenant_modules (tenant_id, module_name, version, enabled, installed_at, settings)
                    VALUES (%s, %s, %s, TRUE, now(), %s::jsonb)
                    ON CONFLICT (tenant_id, module_name)
                    DO UPDATE SET version = EXCLUDED.version, enabled = TRUE, settings = EXCLUDED.settings
                    """,
                    (tenant_id, module_name, manifest.version, settings_str),
                )

                # 2. Đăng ký model_registry (Q2 Aliasing)
                for m in manifest.models:
                    model_name = m["model_name"]
                    table_name = m["table_name"]
                    label_json = json.dumps(m.get("label", {model_name: model_name}))
                    conn.execute(
                        """
                        INSERT INTO model_registry (tenant_id, model_name, module_name, table_name, label, is_syncable)
                        VALUES (%s, %s, %s, %s, %s::jsonb, TRUE)
                        ON CONFLICT (tenant_id, model_name)
                        DO UPDATE SET module_name = EXCLUDED.module_name, table_name = EXCLUDED.table_name, label = EXCLUDED.label
                        """,
                        (tenant_id, model_name, module_name, table_name, label_json),
                    )

                conn.commit()
        else:
            from database import get_db_connection
            conn = get_db_connection()
            try:
                cur = conn.cursor()
                cur.execute(
                    """
                    INSERT OR REPLACE INTO tenant_modules (tenant_id, module_name, version, enabled, installed_at, settings)
                    VALUES (?, ?, ?, 1, ?, ?)
                    """,
                    (tenant_id, module_name, manifest.version, now_iso, settings_str),
                )
                for m in manifest.models:
                    model_name = m["model_name"]
                    table_name = m["table_name"]
                    label_str = json.dumps(m.get("label", {model_name: model_name}))
                    cur.execute(
                        """
                        INSERT OR REPLACE INTO model_registry (tenant_id, model_name, module_name, table_name, label, is_syncable)
                        VALUES (?, ?, ?, ?, ?, 1)
                        """,
                        (tenant_id, model_name, module_name, table_name, label_str),
                    )
                conn.commit()
            finally:
                conn.close()

        return True

    def enable_module(self, module_name: str, tenant_id: str = "default") -> bool:
        """Kích hoạt module cho tenant."""
        if module_name not in self.manifests:
            raise ValueError(f"Module '{module_name}' không tồn tại.")

        if not self.is_module_installed(module_name, tenant_id):
            return self.install_module(module_name, tenant_id)

        backend = CONFIG.db_backend
        if backend == "postgres":
            from db_postgres import pg_connection
            with pg_connection() as conn:
                conn.execute(
                    "UPDATE tenant_modules SET enabled = TRUE WHERE tenant_id = %s AND module_name = %s",
                    (tenant_id, module_name),
                )
                conn.commit()
        else:
            from database import get_db_connection
            conn = get_db_connection()
            try:
                conn.execute(
                    "UPDATE tenant_modules SET enabled = 1 WHERE tenant_id = ? AND module_name = ?",
                    (tenant_id, module_name),
                )
                conn.commit()
            finally:
                conn.close()

        return True

    def disable_module(self, module_name: str, tenant_id: str = "default") -> bool:
        """Tắt module cho tenant (kiểm tra ràng buộc phụ thuộc của module khác)."""
        if module_name == "core":
            raise ValueError("Không thể tắt module 'core' (module nền tảng bắt buộc).")

        # Kiểm tra xem có module nào đang bật mà phụ thuộc vào module này không
        active = set(self.get_active_modules(tenant_id))
        dependents = []
        for other in active:
            if other != module_name and module_name in self.manifests.get(other, ModuleManifest("", "")).depends:
                dependents.append(other)

        if dependents:
            raise ValueError(
                f"Không thể tắt '{module_name}' vì module '{dependents}' đang bật và phụ thuộc vào nó."
            )

        backend = CONFIG.db_backend
        if backend == "postgres":
            from db_postgres import pg_connection
            with pg_connection() as conn:
                conn.execute(
                    "UPDATE tenant_modules SET enabled = FALSE WHERE tenant_id = %s AND module_name = %s",
                    (tenant_id, module_name),
                )
                conn.commit()
        else:
            from database import get_db_connection
            conn = get_db_connection()
            try:
                conn.execute(
                    "UPDATE tenant_modules SET enabled = 0 WHERE tenant_id = ? AND module_name = ?",
                    (tenant_id, module_name),
                )
                conn.commit()
            finally:
                conn.close()

        return True

    def is_module_installed(self, module_name: str, tenant_id: str = "default") -> bool:
        backend = CONFIG.db_backend
        if backend == "postgres":
            from db_postgres import pg_connection
            with pg_connection() as conn:
                row = conn.execute(
                    "SELECT 1 FROM tenant_modules WHERE tenant_id = %s AND module_name = %s",
                    (tenant_id, module_name),
                ).fetchone()
                return row is not None
        else:
            from database import get_db_connection
            conn = get_db_connection()
            try:
                row = conn.execute(
                    "SELECT 1 FROM tenant_modules WHERE tenant_id = ? AND module_name = ?",
                    (tenant_id, module_name),
                ).fetchone()
                return row is not None
            finally:
                conn.close()

    def is_module_enabled(self, module_name: str, tenant_id: str = "default") -> bool:
        """Kiểm tra xem module có đang được kích hoạt cho tenant_id hay không."""
        manifest = self.manifests.get(module_name)
        if not manifest:
            return False

        backend = CONFIG.db_backend
        if backend == "postgres":
            from db_postgres import pg_connection
            with pg_connection() as conn:
                row = conn.execute(
                    "SELECT enabled FROM tenant_modules WHERE tenant_id = %s AND module_name = %s",
                    (tenant_id, module_name),
                ).fetchone()
                if row is not None:
                    return bool(row["enabled"] if isinstance(row, dict) else row[0])
        else:
            from database import get_db_connection
            conn = get_db_connection()
            try:
                row = conn.execute(
                    "SELECT enabled FROM tenant_modules WHERE tenant_id = ? AND module_name = ?",
                    (tenant_id, module_name),
                ).fetchone()
                if row is not None:
                    return bool(row[0])
            finally:
                conn.close()

        # Nếu chưa đăng ký trong tenant_modules, lấy mặc định từ manifest
        return manifest.enabled_by_default

    def get_active_modules(self, tenant_id: str = "default") -> List[str]:
        """Trả về danh sách các module đang bật của tenant."""
        active = []
        for mod in self.sorted_modules:
            if self.is_module_enabled(mod, tenant_id):
                active.append(mod)
        return active

    def get_model_registry(self, tenant_id: str = "default") -> Dict[str, Dict[str, Any]]:
        """Lấy danh sách model logic -> physical mapping cho tenant."""
        registry = {}
        backend = CONFIG.db_backend
        if backend == "postgres":
            from db_postgres import pg_connection
            with pg_connection() as conn:
                rows = conn.execute(
                    "SELECT model_name, module_name, table_name, label, is_syncable FROM model_registry WHERE tenant_id = %s",
                    (tenant_id,),
                ).fetchall()
                for r in rows:
                    mname = r["model_name"] if isinstance(r, dict) else r[0]
                    registry[mname] = dict(r) if isinstance(r, dict) else {
                        "model_name": r[0], "module_name": r[1], "table_name": r[2], "label": r[3], "is_syncable": bool(r[4])
                    }
        else:
            from database import get_db_connection
            conn = get_db_connection()
            try:
                rows = conn.execute(
                    "SELECT model_name, module_name, table_name, label, is_syncable FROM model_registry WHERE tenant_id = ?",
                    (tenant_id,),
                ).fetchall()
                for r in rows:
                    registry[r[0]] = {
                        "model_name": r[0], "module_name": r[1], "table_name": r[2], "label": r[3], "is_syncable": bool(r[4])
                    }
            finally:
                conn.close()

        return registry

    def initialize_default_modules(self, tenant_id: str = "default") -> None:
        """Cài đặt toàn bộ module mặc định theo thứ tự topo."""
        for mod_name in self.sorted_modules:
            manifest = self.manifests[mod_name]
            if manifest.enabled_by_default:
                self.install_module(mod_name, tenant_id)


MODULE_MANAGER = ModuleManager()
