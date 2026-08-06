from __future__ import annotations

import json
import os
import sys
import unittest
from datetime import datetime, timezone
from unittest.mock import Mock, patch

from exporter import (
    COLUMNS,
    acknowledged_cursor_utc,
    build_payload,
    delivery_status,
    publish_payload_to_github_issue,
    report_row,
)


def sample_report() -> dict:
    return {
        "tagNumber": "F-000023",
        "createdAt": "2026-08-05T15:30:00Z",
        "updatedAt": "2026-08-05T17:00:00Z",
        "createdByUid": "user-1",
        "createdByNameSnapshot": "Jefferson Ordonez",
        "sectionCode": "15",
        "sectionNameSnapshot": "MARGARINA",
        "processCode": "1",
        "processNameSnapshot": "ALMACENAMIENTO MRG",
        "equipmentCode": "TACL01",
        "equipmentName": "TANQUE (MG-RBD1)",
        "systemCode": "MTK01",
        "systemNameSnapshot": "Tanque de almacenamiento",
        "destinationId": "SISMAC:15:1:TACL01:MTK01",
        "selectionDepth": "system",
        "locationReference": "Lado norte",
        "leakType": "condensate",
        "leakTypeNameSnapshot": "Condensado",
        "photoUrl": "https://example.test/evidence.jpg",
        "photoProvider": "cloudinary",
        "workOrderCreated": True,
        "workCompleted": False,
        "status": "work_order_created",
        "schemaVersion": 2,
    }


class LeakExporterTests(unittest.TestCase):
    def test_row_uses_local_date_time_and_preserves_codes(self):
        row = report_row("leak-1", sample_report())
        values = dict(zip(COLUMNS, row, strict=True))

        self.assertEqual(values["date"], "2026-08-05")
        self.assertEqual(values["time"], "10:30:00")
        self.assertEqual(values["userName"], "Jefferson Ordonez")
        self.assertEqual(values["sectionCode"], "15")
        self.assertEqual(values["destinationId"], "SISMAC:15:1:TACL01:MTK01")
        self.assertTrue(values["workOrderCreated"])

    def test_payload_is_incremental_and_ready_for_excel(self):
        cursor = datetime(2026, 8, 5, 14, tzinfo=timezone.utc)
        payload = build_payload(
            [("leak-1", sample_report())], cursor_start_utc=cursor
        )

        self.assertEqual(payload["collection"], "leak_reports")
        self.assertEqual(payload["delivery"]["status"], "ready")
        self.assertEqual(payload["delivery"]["rowCount"], 1)
        self.assertEqual(payload["delivery"]["cursorStartUtc"], cursor.isoformat())
        self.assertEqual(
            payload["delivery"]["cursorEndUtc"],
            "2026-08-05T17:00:00+00:00",
        )

    def test_acknowledgement_exposes_cursor(self):
        payload = {
            "delivery": {
                "status": "acknowledged",
                "cursorEndUtc": "2026-08-05T17:00:00Z",
            }
        }
        self.assertEqual(delivery_status(payload), "acknowledged")
        self.assertEqual(
            acknowledged_cursor_utc(payload),
            datetime(2026, 8, 5, 17, tzinfo=timezone.utc),
        )

    @patch.dict(
        os.environ,
        {
            "EE_DATA_REPOSITORY": "owner/private-data",
            "EE_LEAK_ISSUE_NUMBER": "2",
            "EE_DATA_REPO_TOKEN": "test-token",
        },
        clear=False,
    )
    def test_publish_updates_the_dedicated_private_issue(self):
        response = Mock()
        requests_module = Mock()
        requests_module.patch.return_value = response

        with patch.dict(sys.modules, {"requests": requests_module}):
            publish_payload_to_github_issue({"delivery": {"status": "ready"}})

        url = requests_module.patch.call_args.args[0]
        body = requests_module.patch.call_args.kwargs["json"]["body"]
        self.assertEqual(
            url, "https://api.github.com/repos/owner/private-data/issues/2"
        )
        self.assertEqual(json.loads(body)["delivery"]["status"], "ready")
        response.raise_for_status.assert_called_once()


if __name__ == "__main__":
    unittest.main()
