# server/test_event_engine.py
import unittest
import asyncio
import os
import sys

# Ensure server folder is in python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from db_init import init_db
from event_engine import iZiiEventEngine


class TestEventEngine(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        init_db()
        cls.engine = iZiiEventEngine()

    def test_domain_event_mapping(self):
        self.assertEqual(
            self.engine.map_mutation_to_domain_event("mushroom_jobs", "insert", {}),
            "mushroom.job_added"
        )
        self.assertEqual(
            self.engine.map_mutation_to_domain_event("mushroom_employees", "insert", {}),
            "organization.employee_created"
        )
        self.assertEqual(
            self.engine.map_mutation_to_domain_event("purchase_orders", "insert", {}),
            "purchase.order_created"
        )
        self.assertEqual(
            self.engine.map_mutation_to_domain_event("contacts", "insert", {}),
            "customer.registered"
        )

    def test_webhook_crud(self):
        # 1. Register Webhook
        test_url = "http://127.0.0.1:9999/test-webhook"
        sub = self.engine.register_webhook(url=test_url, event_filter="mushroom.*", secret_token="token_123")
        self.assertIsNotNone(sub.get("id"))
        self.assertEqual(sub.get("url"), test_url)

        # 2. List Webhooks
        subs = self.engine.list_webhooks()
        matched = [s for s in subs if s["id"] == sub["id"]]
        self.assertTrue(len(matched) == 1)

        # 3. Unregister Webhook
        deleted = self.engine.unregister_webhook(sub["id"])
        self.assertTrue(deleted)

    def test_dispatch_event_structure(self):
        async def _run():
            payload = await self.engine.dispatch_event(
                event_type="support.email_trigger",
                data={"user_id": "305629", "subject": "Test Support Email"},
            )
            self.assertEqual(payload["event"], "event_reaction")
            self.assertEqual(payload["event_type"], "support.email_trigger")
            self.assertIn("event_id", payload)
            self.assertIn("timestamp", payload)

        asyncio.run(_run())


if __name__ == "__main__":
    unittest.main()
