from dataclasses import dataclass
from datetime import datetime
from typing import Iterator

from google.cloud.firestore_v1 import FieldFilter

from .config import get_settings
from .firebase import get_firestore


MODULE_COLLECTIONS = {
    "traps": "steam_trap_sizing_reports",
    "bare_pipe": "bare_pipe_reports",
    "boilers": "boiler_consumption_readings",
    "pumps": "pump_energy_surveys",
    "leaks": "leak_reports",
}


@dataclass(frozen=True)
class DashboardFilters:
    start: datetime
    end: datetime
    section_id: str = ""
    equipment: str = ""
    user_uid: str = ""
    module: str = "all"
    boiler_id: str = ""
    grouping: str = "day"


def _matches(record: dict, filters: DashboardFilters, module: str) -> bool:
    if filters.section_id:
        section = str(record.get("sectionId") or record.get("section") or "")
        aliases = {
            "servicios_industriales": {"Calderas", "Servicios Industriales"},
            "confiteria_galleteria": {"Confiteria", "Confiteria y Galleteria"},
            "aceites": {"Envase", "Aceites"},
        }
        if section != filters.section_id and section not in aliases.get(
            filters.section_id, set()
        ):
            return False
    if filters.equipment:
        equipment = str(
            record.get("equipmentNameNormalized")
            or record.get("equipmentName")
            or record.get("boilerName")
            or record.get("pumpTag")
            or ""
        ).lower()
        if filters.equipment.lower() not in equipment:
            return False
    if filters.user_uid and record.get("createdByUid") != filters.user_uid:
        return False
    if module == "boilers" and filters.boiler_id:
        boiler = str(record.get("boilerId") or record.get("boilerName") or "")
        if boiler != filters.boiler_id:
            return False
    return True


def _iter_query(query, max_records: int, batch_size: int) -> Iterator[dict]:
    emitted = 0
    cursor = None
    while emitted < max_records:
        page_query = query.limit(min(batch_size, max_records - emitted))
        if cursor is not None:
            page_query = page_query.start_after(cursor)
        documents = list(page_query.stream())
        if not documents:
            return
        for document in documents:
            data = document.to_dict() or {}
            data["_documentId"] = document.id
            yield data
            emitted += 1
            if emitted >= max_records:
                return
        cursor = documents[-1]
        if len(documents) < batch_size:
            return


def iter_module_records(
    module: str,
    filters: DashboardFilters,
) -> Iterator[dict]:
    settings = get_settings()
    collection_name = MODULE_COLLECTIONS[module]
    collection = get_firestore().collection(collection_name)
    seen: set[str] = set()

    timestamp_query = (
        collection.where(filter=FieldFilter("createdAt", ">=", filters.start))
        .where(filter=FieldFilter("createdAt", "<=", filters.end))
        .order_by("createdAt")
    )
    legacy_query = (
        collection.where(
            filter=FieldFilter("createdAt", ">=", filters.start.isoformat())
        )
        .where(filter=FieldFilter("createdAt", "<=", filters.end.isoformat()))
        .order_by("createdAt")
    )
    for query in (timestamp_query, legacy_query):
        for record in _iter_query(
            query,
            settings.dashboard_query_limit,
            settings.dashboard_batch_size,
        ):
            document_id = record["_documentId"]
            if document_id in seen or not _matches(record, filters, module):
                continue
            seen.add(document_id)
            yield record


def load_filtered_records(filters: DashboardFilters) -> dict[str, list[dict]]:
    modules = (
        MODULE_COLLECTIONS.keys()
        if filters.module == "all"
        else [filters.module]
    )
    result = {name: [] for name in MODULE_COLLECTIONS}
    for module in modules:
        result[module] = list(iter_module_records(module, filters))
    return result
