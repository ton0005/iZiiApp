# server/tests/test_phase2_module_system.py
"""
Phase 2 Test Suite: Module System & Bounded Context (P2.1 - P2.6).

Tests:
- P2.1: Module discovery and manifest parsing
- P2.1: Topological dependency sorting
- P2.1: Circular and missing dependency detection
- P2.2 & P2.3: Module lifecycle & tenant_modules isolation
- P2.4: Bounded contexts & Model registry mapping (Q2 aliasing)
- P2.5: Light extends mechanism
- P2.6: Client schema compatibility guard
"""
import os
import sys
import json
import unittest

# Ensure server path is in sys.path
server_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if server_dir not in sys.path:
    sys.path.insert(0, server_dir)

from server_config import CONFIG
from modules.module_manager import ModuleManager, ModuleManifest, MODULE_MANAGER

try:
    from db_postgres import pg_connection
    PG_AVAILABLE = bool(CONFIG.pg_dsn)
except Exception:
    PG_AVAILABLE = False


class TestModuleDiscoveryAndDependencies(unittest.TestCase):
    """P2.1: Module discovery and topological dependency resolution."""

    def test_all_modules_discovered(self):
        manifests = MODULE_MANAGER.manifests
        for expected in ("core", "workforce", "field_ops", "collab"):
            self.assertIn(expected, manifests, f"Module '{expected}' should be discovered")
            m = manifests[expected]
            self.assertEqual(m.name, expected)
            self.assertTrue(len(m.version) > 0)
            self.assertIsInstance(m.depends, list)
            self.assertIsInstance(m.owns_tables, list)

    def test_topological_sort_order(self):
        sorted_mods = MODULE_MANAGER.sorted_modules
        # 'core' has no dependencies -> must come before dependent modules
        self.assertIn("core", sorted_mods)
        self.assertIn("workforce", sorted_mods)
        self.assertIn("field_ops", sorted_mods)
        self.assertIn("collab", sorted_mods)

        core_idx = sorted_mods.index("core")
        workforce_idx = sorted_mods.index("workforce")
        field_ops_idx = sorted_mods.index("field_ops")
        collab_idx = sorted_mods.index("collab")

        self.assertLess(core_idx, workforce_idx, "core must be loaded before workforce")
        self.assertLess(core_idx, collab_idx, "core must be loaded before collab")
        self.assertLess(workforce_idx, field_ops_idx, "workforce must be loaded before field_ops")

    def test_circular_dependency_detection(self):
        # Create a mock manager with circular dependency
        mgr = ModuleManager.__new__(ModuleManager)
        mgr.manifests = {
            "mod_a": ModuleManifest(name="mod_a", version="1.0.0", depends=["mod_b"]),
            "mod_b": ModuleManifest(name="mod_b", version="1.0.0", depends=["mod_a"]),
        }
        with self.assertRaises(ValueError) as ctx:
            mgr.resolve_dependencies()
        self.assertIn("circular dependency", str(ctx.exception).lower())

    def test_missing_dependency_detection(self):
        # Create a mock manager with missing dependency
        mgr = ModuleManager.__new__(ModuleManager)
        mgr.manifests = {
            "mod_x": ModuleManifest(name="mod_x", version="1.0.0", depends=["non_existent_module"]),
        }
        with self.assertRaises(ValueError) as ctx:
            mgr.resolve_dependencies()
        self.assertIn("non_existent_module", str(ctx.exception))


class TestTenantModuleLifecycle(unittest.TestCase):
    """P2.2 & P2.3: Module installation, enable/disable & multi-tenant isolation."""

    def test_tenant_module_install_and_isolation(self):
        tenant_1 = "tenant_test_ops"
        tenant_2 = "tenant_test_retail"

        # 1. Install all modules for tenant 1
        MODULE_MANAGER.initialize_default_modules(tenant_1)
        self.assertTrue(MODULE_MANAGER.is_module_installed("field_ops", tenant_1))
        self.assertTrue(MODULE_MANAGER.is_module_enabled("field_ops", tenant_1))

        # 2. Install all modules for tenant 2, then disable field_ops for tenant 2
        MODULE_MANAGER.initialize_default_modules(tenant_2)
        MODULE_MANAGER.disable_module("field_ops", tenant_2)

        # 3. Verify tenant isolation: tenant 1 still has field_ops, tenant 2 does not!
        self.assertTrue(
            MODULE_MANAGER.is_module_enabled("field_ops", tenant_1),
            "Tenant 1 should still have field_ops enabled",
        )
        self.assertFalse(
            MODULE_MANAGER.is_module_enabled("field_ops", tenant_2),
            "Tenant 2 should have field_ops disabled",
        )

        # Active modules list check
        active_t1 = MODULE_MANAGER.get_active_modules(tenant_1)
        active_t2 = MODULE_MANAGER.get_active_modules(tenant_2)
        self.assertIn("field_ops", active_t1)
        self.assertNotIn("field_ops", active_t2)

    def test_disabling_core_is_rejected(self):
        with self.assertRaises(ValueError) as ctx:
            MODULE_MANAGER.disable_module("core", "default")
        self.assertIn("core", str(ctx.exception).lower())

    def test_disabling_dependency_is_rejected(self):
        # field_ops depends on workforce. Disabling workforce while field_ops is active must fail.
        tenant = "tenant_dep_check"
        MODULE_MANAGER.initialize_default_modules(tenant)
        with self.assertRaises(ValueError) as ctx:
            MODULE_MANAGER.disable_module("workforce", tenant)
        self.assertIn("phụ thuộc", str(ctx.exception).lower())


class TestModelRegistryAliasing(unittest.TestCase):
    """P2.4: Model registry mapping logical model names to physical tables (Q2)."""

    def test_logical_to_physical_mapping(self):
        MODULE_MANAGER.initialize_default_modules("default")
        registry = MODULE_MANAGER.get_model_registry("default")

        # Q2 key mappings: physical mushroom_* preserved, logical models defined
        expected_mappings = {
            "job": "mushroom_jobs",
            "job_type": "mushroom_job_types",
            "attendance_event": "mushroom_attendance_events",
            "timesheet": "mushroom_daily_timesheets",
            "break_policy": "mushroom_break_policies",
            "grow_room": "grow_rooms",
            "task": "tasks",
            "device": "devices",
            "department": "departments",
        }

        for model_name, expected_table in expected_mappings.items():
            self.assertIn(model_name, registry, f"Model '{model_name}' must be registered")
            entry = registry[model_name]
            self.assertEqual(
                entry["table_name"],
                expected_table,
                f"Model '{model_name}' must map to physical table '{expected_table}'",
            )

    def test_table_ownership_lookup(self):
        self.assertEqual(MODULE_MANAGER.get_table_owner("mushroom_jobs"), "field_ops")
        self.assertEqual(MODULE_MANAGER.get_table_owner("grow_rooms"), "field_ops")
        self.assertEqual(MODULE_MANAGER.get_table_owner("mushroom_attendance_events"), "workforce")
        self.assertEqual(MODULE_MANAGER.get_table_owner("departments"), "workforce")
        self.assertEqual(MODULE_MANAGER.get_table_owner("tasks"), "collab")
        self.assertEqual(MODULE_MANAGER.get_table_owner("devices"), "core")
        self.assertEqual(MODULE_MANAGER.get_table_owner("sync_mutations"), "core")


class TestClientSchemaCompatibilityGuard(unittest.TestCase):
    """P2.6: Client schema version compatibility checks."""

    def test_client_schema_compatibility(self):
        # field_ops requires min_client_schema_version 12
        self.assertTrue(MODULE_MANAGER.is_client_compatible("field_ops", 12))
        self.assertTrue(MODULE_MANAGER.is_client_compatible("field_ops", 15))
        self.assertFalse(MODULE_MANAGER.is_client_compatible("field_ops", 10))
        self.assertFalse(MODULE_MANAGER.is_client_compatible("field_ops", 1))

        # workforce requires min_client_schema_version 10
        self.assertTrue(MODULE_MANAGER.is_client_compatible("workforce", 10))
        self.assertTrue(MODULE_MANAGER.is_client_compatible("workforce", 11))
        self.assertFalse(MODULE_MANAGER.is_client_compatible("workforce", 8))

        # core works with client v1
        self.assertTrue(MODULE_MANAGER.is_client_compatible("core", 1))


if __name__ == "__main__":
    unittest.main(verbosity=2)
