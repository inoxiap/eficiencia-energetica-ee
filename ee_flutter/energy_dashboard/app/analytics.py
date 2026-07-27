from collections import Counter, defaultdict
from datetime import datetime, timezone
from math import sqrt
from statistics import mean
from typing import Any


def number(value: Any) -> float | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        try:
            return float(value)
        except ValueError:
            return None
    return None


def timestamp(value: Any) -> datetime | None:
    if isinstance(value, datetime):
        return value
    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return None
    return None


def nested(record: dict, path: str) -> Any:
    current: Any = record
    for part in path.split("."):
        if not isinstance(current, dict):
            return None
        current = current.get(part)
    return current


def first_number(record: dict, *paths: str) -> float | None:
    for path in paths:
        value = number(nested(record, path))
        if value is not None:
            return value
    return None


def bucket_label(value: datetime | None, grouping: str) -> str:
    if value is None:
        return "Sin fecha"
    if grouping == "hour":
        return value.strftime("%Y-%m-%d %H:00")
    if grouping == "week":
        year, week, _ = value.isocalendar()
        return f"{year}-S{week:02d}"
    if grouping == "month":
        return value.strftime("%Y-%m")
    return value.strftime("%Y-%m-%d")


def section_name(record: dict) -> str:
    return str(
        record.get("sectionNameSnapshot")
        or record.get("section")
        or "Sin seccion"
    )


def validated_boiler_consumption(records: list[dict]) -> list[dict]:
    grouped: dict[str, list[dict]] = defaultdict(list)
    for record in records:
        boiler = str(record.get("boilerId") or record.get("boilerName") or "")
        grouped[boiler].append(record)

    output: list[dict] = []
    for boiler, items in grouped.items():
        items.sort(
            key=lambda item: timestamp(item.get("recordedAt"))
            or datetime.min.replace(tzinfo=timezone.utc)
        )
        previous: dict[str, float | None] | None = None
        raw_history: list[dict[str, float | None]] = []
        for item in items:
            raw = {
                "bunker": first_number(item, "bunkerValue", "fuelTotal"),
                "water": first_number(item, "waterValue", "waterTotal"),
                "steam": first_number(item, "steamValue", "steamTotal"),
            }
            mode = str(item.get("readingMode") or "cumulative_meter")
            values: dict[str, float | None] = {}
            for metric, legacy_field in (
                ("bunker", "fuelConsumption"),
                ("water", "waterConsumption"),
                ("steam", "steamConsumption"),
            ):
                explicit = first_number(
                    item,
                    metric + "IntervalConsumption",
                    legacy_field,
                )
                if mode == "interval_consumption":
                    values[metric] = raw[metric]
                elif explicit is not None and explicit >= 0:
                    values[metric] = explicit
                elif previous is not None and raw[metric] is not None:
                    delta = raw[metric] - previous[metric] if previous[metric] is not None else None
                    values[metric] = delta if delta is not None and delta >= 0 else None
                else:
                    values[metric] = None
            previous = raw
            raw_history.append(raw)
            output.append(
                {
                    "boiler": boiler,
                    "recordedAt": timestamp(item.get("recordedAt")),
                    "bunker": values["bunker"],
                    "water": values["water"],
                    "steam": values["steam"],
                    "record": item,
                }
            )
    return output


def _series(points: dict[str, float]) -> dict:
    labels = sorted(points)
    return {"labels": labels, "values": [points[label] for label in labels]}


def _counter(counter: Counter) -> dict:
    labels = sorted(counter)
    return {"labels": labels, "values": [counter[label] for label in labels]}


def _outlier_flags(values: list[float | None]) -> list[bool]:
    valid = [value for value in values if value is not None]
    if len(valid) < 4:
        return [False] * len(values)
    average = mean(valid)
    deviation = sqrt(sum((value - average) ** 2 for value in valid) / len(valid))
    if deviation == 0:
        return [False] * len(values)
    return [
        value is not None and abs(value - average) > 3 * deviation
        for value in values
    ]


def build_dashboard(
    records: dict[str, list[dict]],
    grouping: str,
    start: datetime,
    end: datetime,
) -> dict:
    traps = records.get("traps", [])
    bare = records.get("bare_pipe", [])
    boiler_raw = records.get("boilers", [])
    pumps = records.get("pumps", [])
    leaks = records.get("leaks", [])
    boiler = validated_boiler_consumption(boiler_raw)

    trap_time: Counter = Counter()
    trap_sections: Counter = Counter()
    trap_types: Counter = Counter()
    trap_methods: Counter = Counter()
    trap_equipment: Counter = Counter()
    for item in traps:
        trap_time[bucket_label(timestamp(item.get("createdAt")), grouping)] += 1
        trap_sections[section_name(item)] += 1
        trap_types[str(item.get("applicationTypeNameSnapshot") or item.get("applicationTypeId") or "Sin tipo")] += 1
        trap_methods[str(item.get("calculationMethod") or "historico")] += 1
        trap_equipment[
            str(item.get("equipmentName") or item.get("sectionNameSnapshot") or "Historico")
        ] += 1

    pipe_meters: defaultdict[str, float] = defaultdict(float)
    pipe_loss: defaultdict[str, float] = defaultdict(float)
    pipe_diameters: defaultdict[str, float] = defaultdict(float)
    pipe_time: Counter = Counter()
    pipe_top: list[dict] = []
    for item in bare:
        section = section_name(item)
        length = first_number(item, "lengthValue", "lengthMeters") or 0
        loss = first_number(item, "results.heatLossKw", "calculation.heatLossKw") or 0
        pipe_meters[section] += length
        pipe_loss[section] += loss
        pipe_diameters[str(item.get("diameterLabel") or "Sin diametro")] += length
        pipe_time[bucket_label(timestamp(item.get("createdAt")), grouping)] += 1
        pipe_top.append(
            {
                "section": section,
                "equipment": item.get("equipmentName") or "Registro historico",
                "lossKw": loss,
                "lengthM": length,
            }
        )
    pipe_top.sort(key=lambda item: item["lossKw"], reverse=True)

    boiler_series: dict[str, defaultdict[str, float]] = {
        "bunker": defaultdict(float),
        "water": defaultdict(float),
        "steam": defaultdict(float),
    }
    boiler_share: defaultdict[str, float] = defaultdict(float)
    boiler_totals = {"bunker": 0.0, "water": 0.0, "steam": 0.0}
    bunker_values = [item["bunker"] for item in boiler]
    outlier_flags = _outlier_flags(bunker_values)
    outliers = 0
    for index, item in enumerate(boiler):
        label = bucket_label(item["recordedAt"], grouping)
        for metric in boiler_totals:
            value = item[metric]
            if value is not None:
                boiler_totals[metric] += value
                boiler_series[metric][label] += value
        if item["bunker"] is not None:
            boiler_share[item["boiler"]] += item["bunker"]
        if outlier_flags[index]:
            outliers += 1

    pump_power: defaultdict[str, float] = defaultdict(float)
    pump_count: Counter = Counter()
    pump_hp: list[float] = []
    pump_kw: list[float] = []
    pump_tags: list[str] = []
    pump_unbalance: list[float] = []
    confidence: Counter = Counter()
    demand_top: list[dict] = []
    before_after: defaultdict[str, dict] = defaultdict(dict)
    power_ranges: Counter = Counter()
    candidates: list[dict] = []
    total_pump_power = 0.0
    total_pump_energy = 0.0
    for item in pumps:
        section = section_name(item)
        power = first_number(
            item,
            "measuredInputPowerKw",
            "estimatedInputPowerKw",
            "results.inputPowerKw",
        ) or 0
        hp = first_number(item, "nominalPowerHp") or 0
        energy = first_number(item, "annualEnergyKwh") or 0
        tag = str(item.get("pumpTag") or item.get("assetId") or "Sin tag")
        pump_power[section] += power
        pump_count[section] += 1
        total_pump_power += power
        total_pump_energy += energy
        pump_hp.append(hp)
        pump_kw.append(power)
        pump_tags.append(tag)
        pump_unbalance.append(
            first_number(item, "results.currentUnbalancePercent") or 0
        )
        confidence[str(item.get("confidenceLevel") or nested(item, "results.confidenceLevel") or "low")] += 1
        demand_top.append({"tag": tag, "section": section, "powerKw": power})
        if hp <= 5:
            power_ranges["0-5 HP"] += 1
        elif hp <= 20:
            power_ranges["5-20 HP"] += 1
        elif hp <= 50:
            power_ranges["20-50 HP"] += 1
        else:
            power_ranges[">50 HP"] += 1
        if item.get("candidateForHydraulicReview") is True or nested(
            item, "results.candidateForHydraulicReview"
        ) is True:
            candidates.append(
                {"tag": tag, "section": section, "powerKw": power}
            )
        asset = str(item.get("assetId") or "")
        survey_type = str(item.get("surveyType") or "")
        if asset and survey_type:
            before_after[asset][survey_type] = power
    demand_top.sort(key=lambda item: item["powerKw"], reverse=True)
    savings = []
    for asset, values in before_after.items():
        if "baseline" in values and "post_improvement" in values:
            savings.append(
                {
                    "assetId": asset,
                    "baselineKw": values["baseline"],
                    "postKw": values["post_improvement"],
                    "savedKw": values["baseline"] - values["post_improvement"],
                }
            )

    leak_types: Counter = Counter()
    leak_sections: Counter = Counter()
    leak_statuses: Counter = Counter()
    leak_time: Counter = Counter()
    leak_rows: list[dict] = []
    for item in leaks:
        type_name = str(
            item.get("leakTypeNameSnapshot")
            or item.get("leakType")
            or "Sin tipo"
        )
        section = section_name(item)
        status_name = (
            "Ejecutada"
            if item.get("workCompleted") is True
            else "Con OT"
            if item.get("workOrderCreated") is True
            else "Sin OT"
        )
        leak_types[type_name] += 1
        leak_sections[section] += 1
        leak_statuses[status_name] += 1
        leak_time[bucket_label(timestamp(item.get("createdAt")), grouping)] += 1
        leak_rows.append(
            {
                "tag": item.get("tagNumber") or "Sin numero",
                "type": type_name,
                "section": section,
                "equipment": item.get("equipmentName") or "",
                "status": status_name,
            }
        )

    unique_hours = {
        (item["boiler"], item["recordedAt"].replace(minute=0, second=0, microsecond=0))
        for item in boiler
        if item["recordedAt"] is not None
    }
    boiler_count = len({item["boiler"] for item in boiler})
    expected_hours = max(1, int((end - start).total_seconds() // 3600) + 1)
    expected_points = expected_hours * max(1, boiler_count)
    coverage = min(100.0, len(unique_hours) / expected_points * 100)

    incomplete = 0
    for module_records in records.values():
        for item in module_records:
            if not item.get("createdByUid") or not item.get("createdAt"):
                incomplete += 1

    return {
        "kpis": {
            "trapCount": len(traps),
            "barePipeMeters": sum(pipe_meters.values()),
            "thermalLossKw": sum(pipe_loss.values()),
            "bunkerTotal": boiler_totals["bunker"],
            "waterTotal": boiler_totals["water"],
            "steamTotal": boiler_totals["steam"],
            "pumpCount": len(pumps),
            "pumpPowerKw": total_pump_power,
            "pumpEnergyKwh": total_pump_energy,
            "coveragePercent": coverage,
            "incompleteRecords": incomplete,
            "boilerOutliers": outliers,
            "leakCount": len(leaks),
            "openLeakCount": sum(
                1 for item in leaks if item.get("workCompleted") is not True
            ),
        },
        "traps": {
            "time": _counter(trap_time),
            "sections": _counter(trap_sections),
            "types": _counter(trap_types),
            "methods": _counter(trap_methods),
            "equipment": _counter(trap_equipment),
        },
        "barePipe": {
            "metersBySection": _series(pipe_meters),
            "lossBySection": _series(pipe_loss),
            "metersByDiameter": _series(pipe_diameters),
            "time": _counter(pipe_time),
            "top": pipe_top[:20],
        },
        "boilers": {
            "bunker": _series(boiler_series["bunker"]),
            "water": _series(boiler_series["water"]),
            "steam": _series(boiler_series["steam"]),
            "share": _series(boiler_share),
            "totals": boiler_totals,
        },
        "pumps": {
            "powerBySection": _series(pump_power),
            "countBySection": _counter(pump_count),
            "hp": pump_hp,
            "kw": pump_kw,
            "tags": pump_tags,
            "currentUnbalance": pump_unbalance,
            "confidence": _counter(confidence),
            "powerRanges": _counter(power_ranges),
            "topDemand": demand_top[:20],
            "candidates": candidates[:50],
            "savings": savings,
        },
        "leaks": {
            "types": _counter(leak_types),
            "sections": _counter(leak_sections),
            "statuses": _counter(leak_statuses),
            "time": _counter(leak_time),
            "rows": leak_rows[:100],
        },
    }
