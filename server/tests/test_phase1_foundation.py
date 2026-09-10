# server/tests/test_phase1_foundation.py
"""
Phase 1 Foundation Test Suite:
- P1.1: Automatic audit fields (created_by, created_at, updated_by, updated_at,
        last_mutation_id, last_seq, deleted_at, is_seed, tenant_id)
- P1.2: Versioned migration framework (runner.py, schema_migrations, idempotent)
- P1.3: Declarative seed framework (seed_loader.py, noupdate preservation, is_seed flag)
- P1.4 & P1.6: Multi-tenancy & Row-Level Security (RLS) with session variable app.tenant_id
- P1.7: Tombstone deleted_at for soft deletion
- P1.8: Vietnamese text search configuration 'vi' with unaccent
- P1.9: Authentication secret separation (IZIIAPP_ADMIN_SECRET vs IZIIAPP_SERVER_SECRET)
- P1.10: Port guard detection for port conflicts
- P1.11 & P1.12: PostgreSQL migration tool coverage (27 tables, type conversion, defaults)
"""
import os
import sys
import socket
import sqlite3
import unittest
from datetime import datetime, timezone

# Ensure server path is in sys.path
server_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if server_dir not in sys.path:
    sys.path.insert(0, server_dir)

from server_config import CONFIG, is_port_in_use
from security_auth import verify_admin_secret, verify_server_secret
from db_init_postgres import DOMAIN_TABLES, init_db_postgres
from migrations.runner import get_migration_status, run_migrations
from seeds.seed_loader import load_seeds
from migrate_to_postgres import (
    TABLES,
    NOT_MIGRATED,
    _convert_val,
    _assert_table_coverage,
    _assert_source_coverage,
)
from fastapi import HTTPException

try:
    from db_postgres import pg_connection
    PG_AVAILABLE = bool(CONFIG.pg_dsn)
except Exception:
    PG_AVAILABLE = False


class TestAuditColumnsAndDefaults(unittest.TestCase):
    """P1.1: Verification of 8 audit fields + tenant_id on all domain tables."""

    EXPECTED_AUDIT_COLS = {
        "tenant_id",
        "created_by",
        "created_at",
        "updated_by",
        "updated_at",
        "last_mutation_id",
        "last_seq",
        "deleted_at",
        "is_seed",
    }

    @unittest.skipUnless(PG_AVAILABLE, "PostgreSQL not configured")
    def test_postgres_domain_tables_have_audit_columns(self):
        with pg_connection() as pconn:
            for tbl in DOMAIN_TABLES:
                rows = pconn.execute(
                    "SELECT column_name FROM information_schema.columns "
                    "WHERE table_name = %s AND table_schema = 'public'",
                    (tbl,),
                ).fetchall()
                cols = {r["column_name"] if isinstance(r, dict) else r[0] for r in rows}
                missing = self.EXPECTED_AUDIT_COLS - cols
                self.assertEqual(
                    missing,
                    set(),
                    f"Table {tbl} in PostgreSQL is missing audit columns: {missing}",
                )

    def test_sqlite_domain_tables_have_audit_columns(self):
        from database import DB_PATH
        if not os.path.exists(DB_PATH):
            self.skipTest(f"SQLite DB not found at {DB_PATH}")
        sconn = sqlite3.connect(DB_PATH)
        for tbl in DOMAIN_TABLES:
            cols = {
                r[1]
                for r in sconn.execute(f"PRAGMA table_info({tbl})").fetchall()
            }
            missing = self.EXPECTED_AUDIT_COLS - cols
            self.assertEqual(
                missing,
                set(),
                f"Table {tbl} in SQLite is missing audit columns: {missing}",
            )
        sconn.close()


class TestVersionedMigrationRunner(unittest.TestCase):
    """P1.2: Versioned migration framework testing."""

    @unittest.skipUnless(PG_AVAILABLE, "PostgreSQL not configured")
    def test_migration_runner_status_and_idempotency(self):
        # 1. Check migration status
        status = get_migration_status()
        self.assertGreaterEqual(len(status), 3, "Expected at least 3 baseline migration files")
        for mig in status:
            self.assertIn("name", mig)
            self.assertIn("applied", mig)

        # 2. Running migrations again should be completely idempotent (0 pending)
        applied = run_migrations()
        self.assertEqual(len(applied), 0, "Second run of migrations must apply 0 files (idempotent)")

        # 3. Verify schema_migrations table records in PostgreSQL
        with pg_connection() as pconn:
            rows = pconn.execute("SELECT name FROM schema_migrations").fetchall()
            applied_names = {r["name"] if isinstance(r, dict) else r[0] for r in rows}
            self.assertIn("0001_initial_schema.sql", applied_names)
            self.assertIn("0002_phase5_domain.sql", applied_names)
            self.assertIn("0003_audit_and_rls.sql", applied_names)


class TestDeclarativeSeedLoader(unittest.TestCase):
    """P1.3: Declarative seed framework with noupdate protection and is_seed flag."""

    @unittest.skipUnless(PG_AVAILABLE, "PostgreSQL not configured")
    def test_seed_loader_and_noupdate_preservation(self):
        # Run all seeds
        results = load_seeds()
        self.assertIn("mushroom_break_policies", results)
        self.assertIn("mushroom_job_types", results)
        self.assertIn("departments", results)

        with pg_connection() as pconn:
            # 1. Verify standard seeded rows exist with is_seed = True / 1
            row = pconn.execute(
                "SELECT id, standard_break_minutes, is_seed FROM mushroom_break_policies "
                "WHERE id = 'default_policy'"
            ).fetchone()
            self.assertIsNotNone(row)
            is_seed_val = row["is_seed"] if isinstance(row, dict) else row[2]
            self.assertTrue(bool(is_seed_val), "Seeded row must have is_seed=True")

            # 2. Simulate customer modifying standard_break_minutes to 45
            pconn.execute(
                "UPDATE mushroom_break_policies SET standard_break_minutes = 45 "
                "WHERE id = 'default_policy'"
            )
            pconn.commit()

            # 3. Run seed loader again
            results2 = load_seeds()
            self.assertGreaterEqual(results2.get("mushroom_break_policies", {}).get("skipped", 0), 1)

            # 4. Verify customer modification was NOT overwritten
            row_after = pconn.execute(
                "SELECT standard_break_minutes FROM mushroom_break_policies "
                "WHERE id = 'default_policy'"
            ).fetchone()
            break_mins = row_after["standard_break_minutes"] if isinstance(row_after, dict) else row_after[0]
            self.assertEqual(
                break_mins,
                45,
                "Seed loader must not overwrite customer modifications on noupdate tables",
            )

            # Revert to standard 30 minutes for cleanliness
            pconn.execute(
                "UPDATE mushroom_break_policies SET standard_break_minutes = 30 "
                "WHERE id = 'default_policy'"
            )
            pconn.commit()


class TestRowLevelSecurityTenantIsolation(unittest.TestCase):
    """P1.4 & P1.6: Row-Level Security isolation with app.tenant_id."""

    @unittest.skipUnless(PG_AVAILABLE, "PostgreSQL not configured")
    def test_rls_isolation_between_tenants(self):
        with pg_connection() as pconn:
            # Ensure test non-superuser role exists and has permissions
            pconn.execute("""
            DO $$
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'izii_test_app_user') THEN
                    CREATE ROLE izii_test_app_user;
                END IF;
            END $$;
            """)
            pconn.execute("GRANT ALL ON ALL TABLES IN SCHEMA public TO izii_test_app_user")
            pconn.execute("GRANT ALL ON SCHEMA public TO izii_test_app_user")
            pconn.commit()

            # Clean up test rows
            pconn.execute("DELETE FROM tasks WHERE id IN ('test_task_t1', 'test_task_t2')")

            # Insert test records for two different tenants
            pconn.execute(
                "INSERT INTO tasks (id, title, tenant_id, created_at, updated_at) "
                "VALUES ('test_task_t1', 'Tenant 1 Task', 'tenant_alpha', now(), now())"
            )
            pconn.execute(
                "INSERT INTO tasks (id, title, tenant_id, created_at, updated_at) "
                "VALUES ('test_task_t2', 'Tenant 2 Task', 'tenant_beta', now(), now())"
            )
            pconn.commit()

            try:
                # Switch to non-superuser app role to enforce RLS
                pconn.execute("SET ROLE izii_test_app_user")

                # Session 1: tenant_alpha
                pconn.execute("SELECT set_config('app.tenant_id', 'tenant_alpha', true)")
                rows_alpha = pconn.execute(
                    "SELECT id FROM tasks WHERE id IN ('test_task_t1', 'test_task_t2')"
                ).fetchall()
                ids_alpha = {r["id"] if isinstance(r, dict) else r[0] for r in rows_alpha}
                self.assertEqual(ids_alpha, {"test_task_t1"}, "Tenant alpha should only see task t1")

                # Session 2: tenant_beta
                pconn.execute("SELECT set_config('app.tenant_id', 'tenant_beta', true)")
                rows_beta = pconn.execute(
                    "SELECT id FROM tasks WHERE id IN ('test_task_t1', 'test_task_t2')"
                ).fetchall()
                ids_beta = {r["id"] if isinstance(r, dict) else r[0] for r in rows_beta}
                self.assertEqual(ids_beta, {"test_task_t2"}, "Tenant beta should only see task t2")

                # Session 3: Wildcard sees both
                pconn.execute("SELECT set_config('app.tenant_id', '*', true)")
                rows_all = pconn.execute(
                    "SELECT id FROM tasks WHERE id IN ('test_task_t1', 'test_task_t2')"
                ).fetchall()
                ids_all = {r["id"] if isinstance(r, dict) else r[0] for r in rows_all}
                self.assertEqual(ids_all, {"test_task_t1", "test_task_t2"}, "Wildcard should see all tasks")

            finally:
                pconn.execute("RESET ROLE")
                pconn.execute("DELETE FROM tasks WHERE id IN ('test_task_t1', 'test_task_t2')")
                pconn.commit()

    @unittest.skipUnless(PG_AVAILABLE, "PostgreSQL not configured")
    def test_rls_enforcement_in_request_pipeline(self):
        """P1.6: Verify that request pipeline sets app.tenant_id via get_db dependency."""
        from dependencies import get_db
        from unittest.mock import MagicMock

        req_alpha = MagicMock()
        req_alpha.headers = {"x-tenant-id": "tenant_alpha"}
        req_alpha.query_params = {}

        req_beta = MagicMock()
        req_beta.headers = {"x-tenant-id": "tenant_beta"}
        req_beta.query_params = {}

        # 1. Test request with tenant_alpha
        gen_a = get_db(req_alpha)
        conn_a = next(gen_a)
        row_a = conn_a.execute("SELECT current_setting('app.tenant_id', true) AS t").fetchone()
        self.assertEqual(row_a["t"] if isinstance(row_a, dict) else row_a[0], "tenant_alpha")
        try:
            next(gen_a)
        except StopIteration:
            pass

        # 2. Test request with tenant_beta
        gen_b = get_db(req_beta)
        conn_b = next(gen_b)
        row_b = conn_b.execute("SELECT current_setting('app.tenant_id', true) AS t").fetchone()
        self.assertEqual(row_b["t"] if isinstance(row_b, dict) else row_b[0], "tenant_beta")
        try:
            next(gen_b)
        except StopIteration:
            pass

        # 3. Test request without headers (defaults to 'default')
        gen_def = get_db(None)
        conn_def = next(gen_def)
        row_def = conn_def.execute("SELECT current_setting('app.tenant_id', true) AS t").fetchone()
        self.assertEqual(row_def["t"] if isinstance(row_def, dict) else row_def[0], "default")
        try:
            next(gen_def)
        except StopIteration:
            pass


class TestVietnameseTextSearch(unittest.TestCase):
    """P1.8: Vietnamese text search configuration 'vi' with unaccent."""

    @unittest.skipUnless(PG_AVAILABLE, "PostgreSQL not configured")
    def test_vietnamese_unaccent_search(self):
        with pg_connection() as pconn:
            # Test unaccent matching
            query = """
            SELECT to_tsvector('vi', 'Phòng Trồng Nấm 33') @@ to_tsquery('vi', 'phong & 33') AS match_phrase,
                   to_tsvector('vi', 'Phòng Trồng Nấm 33') @@ to_tsquery('vi', 'nam') AS match_accent
            """
            row = pconn.execute(query).fetchone()
            match_phrase = row["match_phrase"] if isinstance(row, dict) else row[0]
            match_accent = row["match_accent"] if isinstance(row, dict) else row[1]
            self.assertTrue(match_phrase, "Text search 'vi' must match unaccented 'phong & 33'")
            self.assertTrue(match_accent, "Text search 'vi' must match 'nam' with 'Nấm'")


class TestSoftDeleteTombstone(unittest.TestCase):
    """P1.7: Tombstone deleted_at pattern."""

    @unittest.skipUnless(PG_AVAILABLE, "PostgreSQL not configured")
    def test_soft_delete_tombstone(self):
        with pg_connection() as pconn:
            task_id = "test_tombstone_task"
            pconn.execute("DELETE FROM tasks WHERE id = %s", (task_id,))
            pconn.execute(
                "INSERT INTO tasks (id, title, tenant_id, created_at, updated_at) "
                "VALUES (%s, 'Tombstone Task', 'default', now(), now())",
                (task_id,),
            )
            pconn.commit()

            # Active record before soft delete
            active = pconn.execute(
                "SELECT id FROM tasks WHERE id = %s AND deleted_at IS NULL",
                (task_id,),
            ).fetchone()
            self.assertIsNotNone(active)

            # Perform soft delete (tombstone)
            now_iso = datetime.now(timezone.utc).isoformat()
            pconn.execute(
                "UPDATE tasks SET deleted_at = %s, updated_at = %s WHERE id = %s",
                (now_iso, now_iso, task_id),
            )
            pconn.commit()

            # Active record query must return None
            active_after = pconn.execute(
                "SELECT id FROM tasks WHERE id = %s AND deleted_at IS NULL",
                (task_id,),
            ).fetchone()
            self.assertIsNone(active_after, "Soft-deleted record must not appear in active query")

            # Tombstone record is still present for sync/audit
            tombstone = pconn.execute(
                "SELECT id, deleted_at FROM tasks WHERE id = %s",
                (task_id,),
            ).fetchone()
            self.assertIsNotNone(tombstone)
            deleted_at = tombstone["deleted_at"] if isinstance(tombstone, dict) else tombstone[1]
            self.assertIsNotNone(deleted_at)

            # Cleanup
            pconn.execute("DELETE FROM tasks WHERE id = %s", (task_id,))
            pconn.commit()


class TestSecurityAuthAndPortGuard(unittest.TestCase):
    """P1.9 & P1.10: Admin secret separation and Port Guard."""

    def test_verify_admin_secret_rejection(self):
        # When admin secret is set, wrong secret must raise 401
        if CONFIG.admin_secret:
            with self.assertRaises(HTTPException) as ctx:
                verify_admin_secret("wrong_token_12345")
            self.assertEqual(ctx.exception.status_code, 401)

            with self.assertRaises(HTTPException) as ctx:
                verify_admin_secret(None)
            self.assertEqual(ctx.exception.status_code, 401)

            # Correct token should pass without exception
            try:
                verify_admin_secret(CONFIG.admin_secret)
            except Exception as e:
                self.fail(f"verify_admin_secret raised unexpectedly on valid secret: {e}")

    def test_port_guard_detection(self):
        # 1. Bind a temporary socket to a local port
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.bind(("127.0.0.1", 0))
        bound_port = s.getsockname()[1]
        s.listen(1)

        try:
            # Port guard must report True for occupied port
            self.assertTrue(
                is_port_in_use(bound_port),
                f"Port guard should detect bound port {bound_port}",
            )
        finally:
            s.close()

        # Port guard must report False once socket is closed
        self.assertFalse(
            is_port_in_use(bound_port),
            f"Port guard should report False after port {bound_port} is released",
        )


class TestMigrateToPostgresCoverage(unittest.TestCase):
    """P1.11 & P1.12: Migration table coverage (27 tables) & type conversion."""

    def test_table_coverage_count(self):
        # 27 domain + core tables (plus 3 Phase 2 module system tables = 30)
        self.assertGreaterEqual(
            len(TABLES),
            27,
            f"Expected at least 27 tables in TABLES, found {len(TABLES)}: {[t[0] for t in TABLES]}",
        )

    def test_convert_val_boolean_and_audit_defaults(self):
        # Boolean conversions
        self.assertIs(True, _convert_val("is_seed", 1, "boolean"))
        self.assertIs(True, _convert_val("is_seed", "1", "boolean"))
        self.assertIs(True, _convert_val("is_seed", "true", "boolean"))
        self.assertIs(False, _convert_val("is_seed", 0, "boolean"))
        self.assertIs(False, _convert_val("is_seed", "0", "boolean"))
        self.assertIs(False, _convert_val("is_seed", None, "boolean"))

        # Tenant fallback
        self.assertEqual("default", _convert_val("tenant_id", None, "text"))
        self.assertEqual("default", _convert_val("tenant_id", "", "text"))
        self.assertEqual("custom_tenant", _convert_val("tenant_id", "custom_tenant", "text"))

        # Last seq fallback
        self.assertEqual(0, _convert_val("last_seq", None, "bigint"))
        self.assertEqual(100, _convert_val("last_seq", 100, "bigint"))

        # Created_at fallback
        now_conv = _convert_val("created_at", None, "timestamptz")
        self.assertIsNotNone(now_conv)
        self.assertIn("T", now_conv)

    @unittest.skipUnless(PG_AVAILABLE, "PostgreSQL not configured")
    def test_coverage_assertions(self):
        from database import DB_PATH
        if os.path.exists(DB_PATH):
            sconn = sqlite3.connect(DB_PATH)
            # Both coverage checks should pass cleanly without raising SystemExit
            _assert_source_coverage(sconn)
            sconn.close()

        with pg_connection() as pconn:
            _assert_table_coverage(pconn)


if __name__ == "__main__":
    unittest.main(verbosity=2)
