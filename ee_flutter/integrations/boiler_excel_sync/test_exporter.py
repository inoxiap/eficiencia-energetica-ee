from __future__ import annotations

import json
import os
import sys
import unittest
from datetime import date, datetime, timezone
from unittest.mock import Mock, patch

from exporter import (
    acknowledged_cursor_utc,
    allocate_hourly,
    build_daily_summaries,
    build_intervals,
    build_power_automate_payload,
    cursor_end_for_publication,
    delivery_remaining_dates,
    delivery_status,
    load_github_issue_payload,
    latest_revisions,
    publish_payload_to_github_issue,
    reading_from_dict,
    excel_weeknum_sunday,
    start_of_local_day_utc,
)


def reading(
    document_id: str,
    recorded_at: str,
    bunker: float,
    water: float,
    *,
    revision: int = 1,
    root: str | None = None,
):
    return reading_from_dict(
        document_id,
        {
            "boilerId": "alfa_laval_1200",
            "boilerName": "Caldera Alfa Laval 1200",
            "recordedAt": recorded_at,
            "createdAt": datetime.fromisoformat(
                recorded_at.replace("Z", "+00:00")
            ),
            "bunkerValue": bunker,
            "bunkerUnit": "gal",
            "waterValue": water,
            "waterUnit": "gal",
            "boilerPressurePsi": 150,
            "readingMode": "cumulative_meter",
            "revision": revision,
            "rootRecordId": root or document_id,
        },
    )


class ExporterTests(unittest.TestCase):
    def test_latest_revision_replaces_previous_value(self):
        first = reading("root", "2026-07-24T05:00:00Z", 100, 200)
        corrected = reading(
            "root_r2",
            "2026-07-24T05:00:00Z",
            110,
            210,
            revision=2,
            root="root",
        )
        effective = latest_revisions([first, corrected])
        self.assertEqual([item.document_id for item in effective], ["root_r2"])

    def test_interval_is_allocated_across_closed_hours(self):
        first = reading("a", "2026-07-24T05:30:00Z", 100, 200)
        second = reading("b", "2026-07-24T07:00:00Z", 130, 260)
        intervals = build_intervals([first, second])
        self.assertEqual(intervals[1].bunker_delta_gal, 30)
        allocations = allocate_hourly(intervals)
        self.assertEqual(len(allocations), 2)
        self.assertAlmostEqual(sum(item.bunker_hour_gal or 0 for item in allocations), 30)
        self.assertAlmostEqual(allocations[0].bunker_hour_gal or 0, 10)
        self.assertAlmostEqual(allocations[1].bunker_hour_gal or 0, 20)

    def test_meter_reset_is_flagged_and_not_summed(self):
        first = reading("a", "2026-07-24T05:00:00Z", 100, 200)
        second = reading("b", "2026-07-24T06:00:00Z", 5, 10)
        interval = build_intervals([first, second])[1]
        self.assertIsNone(interval.bunker_delta_gal)
        self.assertIsNone(interval.water_delta_gal)
        self.assertEqual(interval.quality, "Reinicio o lectura menor")
        self.assertEqual(allocate_hourly([interval]), [])

    def test_daily_total_matches_hourly_allocations(self):
        first = reading("a", "2026-07-24T05:30:00Z", 100, 200)
        second = reading("b", "2026-07-24T07:00:00Z", 130, 260)
        intervals = build_intervals([first, second])
        allocations = allocate_hourly(intervals)
        summaries = build_daily_summaries([first, second], allocations)
        self.assertEqual(len(summaries), 1)
        self.assertAlmostEqual(summaries[0].bunker_gal, 30)
        self.assertAlmostEqual(summaries[0].water_gal, 60)
        self.assertEqual(summaries[0].pressure_average_psi, 150)

    def test_week_number_matches_excel_default_sunday_system(self):
        self.assertEqual(excel_weeknum_sunday(datetime(2026, 1, 1).date()), 1)
        self.assertEqual(excel_weeknum_sunday(datetime(2026, 1, 4).date()), 2)

    def test_power_automate_payload_preserves_raw_and_daily_data(self):
        first = reading("a", "2026-07-24T05:30:00Z", 100, 200)
        second = reading("b", "2026-07-24T07:00:00Z", 130, 260)
        payload = build_power_automate_payload([first, second])
        self.assertEqual(payload["schemaVersion"], 2)
        self.assertEqual(payload["collection"], "boiler_consumption_readings")
        self.assertEqual(len(payload["datasets"]["raw"]["rows"]), 2)
        self.assertEqual(payload["delivery"]["status"], "ready")
        self.assertEqual(payload["delivery"]["rawRowCount"], 2)
        self.assertEqual(
            payload["delivery"]["cursorEndUtc"],
            "2026-07-24T07:00:00+00:00",
        )
        daily = payload["datasets"]["daily"]["rows"]
        self.assertEqual(daily[0][0], "2026-07-24|alfa_laval_1200")
        self.assertAlmostEqual(daily[0][13], 30)
        self.assertAlmostEqual(daily[0][14], 60)

    def test_alfa_new_meter_readings_are_recovered_as_direct_gallons(self):
        converted_by_old_app = reading_from_dict(
            "alfa-new-meter",
            {
                "boilerId": "alfa_laval_1200",
                "boilerName": "Caldera Alfa Laval 1200",
                "recordedAt": "2026-08-19T23:03:00Z",
                "bunkerValue": 575 / 3.79,
                "bunkerUnit": "gal",
                "waterValue": 200,
                "waterUnit": "gal",
                "originalInputs": {
                    "bunker": {
                        "value": 575,
                        "unit": "L",
                        "gallons": 575 / 3.79,
                    }
                },
            },
        )

        self.assertEqual(converted_by_old_app.bunker_total_gal, 575)
        self.assertEqual(converted_by_old_app.bunker_unit, "gal")
        self.assertIn(
            "alfa_bunker_direct_gal_2026_08_19_v1",
            converted_by_old_app.warnings,
        )

    def test_alfa_old_meter_readings_keep_liter_conversion(self):
        old_meter = reading_from_dict(
            "alfa-old-meter",
            {
                "boilerId": "alfa_laval_1200",
                "boilerName": "Caldera Alfa Laval 1200",
                "recordedAt": "2026-08-19T22:59:00Z",
                "bunkerValue": 1000,
                "bunkerUnit": "gal",
                "waterValue": 200,
                "waterUnit": "gal",
                "originalInputs": {
                    "bunker": {"value": 3790, "unit": "L", "gallons": 1000}
                },
            },
        )

        self.assertEqual(old_meter.bunker_total_gal, 1000)
        self.assertNotIn(
            "alfa_bunker_direct_gal_2026_08_19_v1",
            old_meter.warnings,
        )

    def test_incremental_payload_keeps_changed_rows_and_full_affected_day(self):
        first = reading("a", "2026-07-24T05:30:00Z", 100, 200)
        second = reading("b", "2026-07-24T07:00:00Z", 130, 260)
        payload = build_power_automate_payload(
            [first, second],
            changed_since_utc=datetime(
                2026,
                7,
                24,
                6,
                tzinfo=timezone.utc,
            ),
        )
        self.assertEqual(payload["mode"], "incremental")
        self.assertEqual(
            [row[0] for row in payload["datasets"]["raw"]["rows"]],
            ["b"],
        )
        self.assertEqual(
            payload["datasets"]["daily"]["rows"][0][0],
            "2026-07-24|alfa_laval_1200",
        )
        self.assertAlmostEqual(
            payload["datasets"]["daily"]["rows"][0][13],
            30,
        )

    def test_date_payload_uses_context_without_repeating_context_as_raw(self):
        previous = reading("previous", "2026-07-24T04:00:00Z", 100, 200)
        first = reading("first", "2026-07-24T06:00:00Z", 120, 240)
        second = reading("second", "2026-07-24T08:00:00Z", 140, 280)
        following = reading("following", "2026-07-25T06:00:00Z", 360, 720)

        payload = build_power_automate_payload(
            [previous, first, second, following],
            target_local_date=date(2026, 7, 24),
        )

        self.assertEqual(payload["mode"], "date")
        self.assertEqual(payload["affectedDates"], ["2026-07-24"])
        self.assertEqual(
            [row[0] for row in payload["datasets"]["raw"]["rows"]],
            ["first", "second"],
        )
        self.assertEqual(
            [row[0] for row in payload["datasets"]["intervals"]["rows"]],
            ["first", "second"],
        )
        hourly_rows = payload["datasets"]["hourly"]["rows"]
        self.assertTrue(hourly_rows)
        self.assertTrue(
            all(row[2] == "2026-07-24" for row in hourly_rows)
        )
        self.assertEqual(
            payload["datasets"]["daily"]["rows"][0][0],
            "2026-07-24|alfa_laval_1200",
        )

    def test_start_of_local_day_uses_guayaquil_timezone(self):
        result = start_of_local_day_utc(
            datetime(2026, 7, 24, 18, tzinfo=timezone.utc)
        )
        self.assertEqual(result.isoformat(), "2026-07-24T05:00:00+00:00")

    def test_acknowledged_delivery_exposes_cursor(self):
        payload = {
            "delivery": {
                "status": "acknowledged",
                "cursorEndUtc": "2026-07-27T18:00:00Z",
            }
        }
        self.assertEqual(delivery_status(payload), "acknowledged")
        self.assertEqual(
            acknowledged_cursor_utc(payload),
            datetime(2026, 7, 27, 18, tzinfo=timezone.utc),
        )

    def test_queued_dates_keep_cursor_at_confirmed_start(self):
        payload = {
            "delivery": {
                "status": "acknowledged",
                "cursorStartUtc": "2026-07-27T10:00:00Z",
                "cursorEndUtc": "2026-07-27T18:00:00Z",
                "remainingDates": ["2026-07-26", "2026-07-27"],
            }
        }
        self.assertEqual(
            delivery_remaining_dates(payload),
            [date(2026, 7, 26), date(2026, 7, 27)],
        )
        self.assertEqual(
            acknowledged_cursor_utc(payload),
            datetime(2026, 7, 27, 10, tzinfo=timezone.utc),
        )

    def test_date_payload_carries_remaining_dates_and_final_cursor(self):
        first = reading("a", "2026-07-24T05:30:00Z", 100, 200)
        payload = build_power_automate_payload(
            [first],
            target_local_date=date(2026, 7, 24),
            cursor_start_utc=datetime(
                2026,
                7,
                23,
                18,
                tzinfo=timezone.utc,
            ),
            cursor_end_utc=datetime(
                2026,
                7,
                27,
                18,
                tzinfo=timezone.utc,
            ),
            remaining_dates=[date(2026, 7, 25), date(2026, 7, 26)],
        )
        self.assertEqual(
            payload["delivery"]["remainingDates"],
            ["2026-07-25", "2026-07-26"],
        )
        self.assertEqual(
            payload["delivery"]["cursorEndUtc"],
            "2026-07-27T18:00:00+00:00",
        )

    def test_explicit_backfill_preserves_acknowledged_cursor(self):
        acknowledged = datetime(2026, 9, 2, 0, 3, tzinfo=timezone.utc)
        historical = datetime(2026, 8, 20, 3, 3, tzinfo=timezone.utc)

        self.assertEqual(
            cursor_end_for_publication(
                acknowledged_cursor=acknowledged,
                queued_cursor_end=historical,
                explicit_backfill=True,
            ),
            acknowledged,
        )
        self.assertEqual(
            cursor_end_for_publication(
                acknowledged_cursor=acknowledged,
                queued_cursor_end=historical,
                explicit_backfill=False,
            ),
            historical,
        )

    @patch.dict(
        os.environ,
        {
            "EE_DATA_REPOSITORY": "owner/private-data",
            "EE_DATA_ISSUE_NUMBER": "7",
            "EE_DATA_REPO_TOKEN": "secret-token",
        },
        clear=False,
    )
    def test_load_issue_payload_reads_acknowledgement(self):
        response = Mock()
        response.json.return_value = {
            "body": json.dumps(
                {
                    "schemaVersion": 2,
                    "delivery": {"status": "acknowledged"},
                }
            )
        }
        requests_module = Mock()
        requests_module.get.return_value = response

        with patch.dict(sys.modules, {"requests": requests_module}):
            payload = load_github_issue_payload()

        self.assertEqual(delivery_status(payload), "acknowledged")
        requests_module.get.assert_called_once()
        response.raise_for_status.assert_called_once()

    @patch.dict(
        os.environ,
        {
            "EE_DATA_REPOSITORY": "owner/private-data",
            "EE_DATA_ISSUE_NUMBER": "7",
            "EE_DATA_REPO_TOKEN": "secret-token",
        },
        clear=False,
    )
    def test_publish_payload_updates_private_issue(self):
        response = Mock()
        requests_module = Mock()
        requests_module.patch.return_value = response
        payload = {"schemaVersion": 1, "datasets": {}}

        with patch.dict(sys.modules, {"requests": requests_module}):
            publish_payload_to_github_issue(payload)

        requests_module.patch.assert_called_once()
        url = requests_module.patch.call_args.args[0]
        kwargs = requests_module.patch.call_args.kwargs
        self.assertEqual(
            url,
            "https://api.github.com/repos/owner/private-data/issues/7",
        )
        self.assertEqual(
            json.loads(kwargs["json"]["body"]),
            payload,
        )
        self.assertEqual(
            kwargs["headers"]["Authorization"],
            "Bearer secret-token",
        )
        response.raise_for_status.assert_called_once()


if __name__ == "__main__":
    unittest.main()
