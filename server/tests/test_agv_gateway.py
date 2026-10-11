# server/tests/test_agv_gateway.py
"""
Test Suite Phase 3, Sprint 9:
VDA 5050 AGV / AMR Gateway, Cold Store Door Interlock, and FAT Commissioning.
"""
import unittest
from starlette.testclient import TestClient

import app as app_module


class TestAgvGatewayApi(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app_module.app)

    def test_get_fleet_status(self):
        """Validates AGV fleet listing and door interlock configuration."""
        res = self.client.get("/api/v1/agv/fleet")
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data["status"], "success")
        self.assertGreaterEqual(len(data["fleet"]), 1)
        self.assertGreaterEqual(len(data["doors"]), 1)

        serials = [a["serialNumber"] for a in data["fleet"]]
        self.assertIn("AGV-COSTA-01", serials)

    def test_dispatch_vda5050_order(self):
        """Tests VDA 5050 v2.0 standardized pallet transfer mission dispatch."""
        payload = {
            "serialNumber": "AGV-COSTA-01",
            "palletLpn": "LPN-20261005-0042",
            "sourceLocationCode": "WH1-CONVEYOR-EXIT",
            "destLocationCode": "WH1-COLD-A01-R03-L2",
            "productSku": "MUSH-CUP-4KG",
            "quantity": 72.0,
        }
        res = self.client.post("/api/v1/agv/orders", json=payload)
        self.assertEqual(res.status_code, 201)
        data = res.json()
        self.assertEqual(data["status"], "success")
        order = data["order"]
        self.assertTrue(order["orderId"].startswith("VDA-ORD-"))

        vda = order["vdaOrder"]
        self.assertEqual(vda["version"], "2.0.0")
        self.assertEqual(len(vda["nodes"]), 3)
        self.assertEqual(len(vda["edges"]), 2)

        # Node 0: Pick from conveyor exit
        self.assertEqual(vda["nodes"][0]["nodeId"], "WH1-CONVEYOR-EXIT")
        self.assertEqual(vda["nodes"][0]["actions"][0]["actionType"], "pick")

        # Node 2: Door interlock gateway
        self.assertEqual(vda["nodes"][1]["nodeId"], "WH1-COLD-DOOR-01")
        self.assertEqual(vda["nodes"][1]["actions"][0]["actionType"], "door_interlock_open")

        # Node 4: Drop in high cold rack
        self.assertEqual(vda["nodes"][2]["nodeId"], "WH1-COLD-A01-R03-L2")
        self.assertEqual(vda["nodes"][2]["actions"][0]["actionType"], "drop")

    def test_door_interlock_trigger(self):
        """Tests manual or programmatic cold room high-speed roll door relay trigger."""
        payload = {
            "doorId": "DOOR-COLD-01",
            "vehicleId": "AGV-COSTA-01",
            "command": "open",
            "reason": "AGV approached within 4.5m radar envelope",
        }
        res = self.client.post("/api/v1/agv/door-interlock/trigger", json=payload)
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data["status"], "success")
        self.assertEqual(data["doorStatus"], "open")

        # Close door
        payload["command"] = "close"
        res_close = self.client.post("/api/v1/agv/door-interlock/trigger", json=payload)
        self.assertEqual(res_close.status_code, 200)
        self.assertEqual(res_close.json()["doorStatus"], "closed")

    def test_fat_commissioning_report(self):
        """Validates full plant Factory Acceptance Testing (FAT) Commissioning Endpoint."""
        res = self.client.get("/api/v1/agv/fat-commissioning")
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data["overallResult"], "PASSED_COMMISSIONED")
        self.assertEqual(data["stagesCount"], 8)
        self.assertEqual(data["passedStagesCount"], 8)
        self.assertTrue(data["commissioningReportId"].startswith("FAT-COSTA-WMS-"))

        # Verify all 8 stages are present and passed
        stage_names = [s["name"] for s in data["stages"]]
        self.assertTrue(any("MES Harvest" in n for n in stage_names))
        self.assertTrue(any("Conveyor" in n for n in stage_names))
        self.assertTrue(any("Pallet Scale" in n for n in stage_names))
        self.assertTrue(any("VDA 5050 AGV" in n for n in stage_names))
        self.assertTrue(any("FEFO Wave Picking" in n for n in stage_names))
        self.assertTrue(any("Packout Gross-Weight" in n for n in stage_names))
        self.assertTrue(any("BLE Telemetry" in n for n in stage_names))
        self.assertTrue(any("e-PoD" in n for n in stage_names))


if __name__ == "__main__":
    unittest.main()
