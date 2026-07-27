from datetime import datetime, timedelta, timezone

from app.analytics import build_dashboard, validated_boiler_consumption


def test_cumulative_readings_use_positive_deltas_only():
    records = [
        {
            "boilerId": "boiler-1",
            "recordedAt": datetime(2026, 7, 11, 10, tzinfo=timezone.utc),
            "readingMode": "cumulative_meter",
            "bunkerValue": 100,
            "waterValue": 200,
        },
        {
            "boilerId": "boiler-1",
            "recordedAt": datetime(2026, 7, 11, 11, tzinfo=timezone.utc),
            "readingMode": "cumulative_meter",
            "bunkerValue": 112,
            "waterValue": 225,
        },
        {
            "boilerId": "boiler-1",
            "recordedAt": datetime(2026, 7, 11, 12, tzinfo=timezone.utc),
            "readingMode": "cumulative_meter",
            "bunkerValue": 3,
            "waterValue": 5,
        },
    ]

    values = validated_boiler_consumption(records)

    assert values[1]["bunker"] == 12
    assert values[1]["water"] == 25
    assert values[2]["bunker"] is None
    assert values[2]["water"] is None


def test_dashboard_keeps_kw_and_kwh_separate():
    start = datetime(2026, 7, 1, tzinfo=timezone.utc)
    end = start + timedelta(days=1)
    records = {
        "traps": [],
        "bare_pipe": [],
        "boilers": [],
        "pumps": [
            {
                "createdAt": start,
                "sectionNameSnapshot": "Refineria",
                "pumpTag": "P-1",
                "measuredInputPowerKw": 12,
                "annualEnergyKwh": 36000,
                "nominalPowerHp": 20,
                "confidenceLevel": "high",
            }
        ],
    }

    data = build_dashboard(records, "day", start, end)

    assert data["kpis"]["pumpPowerKw"] == 12
    assert data["kpis"]["pumpEnergyKwh"] == 36000
