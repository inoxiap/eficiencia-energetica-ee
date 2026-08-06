from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from typing import Any
from zoneinfo import ZoneInfo


LOCAL_ZONE = ZoneInfo("America/Guayaquil")
COLLECTION_NAME = "leak_reports"
PAYLOAD_SCHEMA_VERSION = 1
COLUMNS = [
    "id",
    "reportNumber",
    "date",
    "time",
    "createdAtUtc",
    "updatedAtUtc",
    "createdByUid",
    "userName",
    "sectionCode",
    "sectionName",
    "processCode",
    "processName",
    "equipmentCode",
    "equipmentName",
    "systemCode",
    "systemName",
    "destinationId",
    "selectionDepth",
    "locationReference",
    "leakType",
    "leakTypeName",
    "photoUrl",
    "photoProvider",
    "workOrderCreated",
    "workCompleted",
    "status",
    "workOrderCreatedAtUtc",
    "workOrderCreatedByName",
    "workCompletedAtUtc",
    "workCompletedByName",
    "notes",
    "appVersion",
    "platform",
    "recordSchemaVersion",
    "source",
    "updatedByUid",
]


def as_datetime(value: Any) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        parsed = value
    elif hasattr(value, "to_datetime"):
        parsed = value.to_datetime()
    else:
        text = str(value).strip().replace("Z", "+00:00")
        if not text:
            return None
        parsed = datetime.fromisoformat(text)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def iso_utc(value: Any) -> str:
    parsed = as_datetime(value)
    return parsed.isoformat() if parsed else ""


def report_row(document_id: str, data: dict[str, Any]) -> list[Any]:
    created_at = as_datetime(data.get("createdAt")) or as_datetime(
        data.get("capturedAtLocal")
    )
    updated_at = as_datetime(data.get("updatedAt")) or created_at
    local_created = created_at.astimezone(LOCAL_ZONE) if created_at else None
    return [
        document_id,
        str(data.get("tagNumber") or ""),
        local_created.date().isoformat() if local_created else "",
        local_created.strftime("%H:%M:%S") if local_created else "",
        created_at.isoformat() if created_at else "",
        updated_at.isoformat() if updated_at else "",
        str(data.get("createdByUid") or ""),
        str(data.get("createdByNameSnapshot") or ""),
        str(data.get("sectionCode") or data.get("sectionId") or ""),
        str(data.get("sectionNameSnapshot") or ""),
        str(data.get("processCode") or ""),
        str(data.get("processNameSnapshot") or ""),
        str(data.get("equipmentCode") or ""),
        str(data.get("equipmentName") or ""),
        str(data.get("systemCode") or ""),
        str(data.get("systemNameSnapshot") or ""),
        str(data.get("destinationId") or ""),
        str(data.get("selectionDepth") or "none"),
        str(data.get("locationReference") or ""),
        str(data.get("leakType") or ""),
        str(data.get("leakTypeNameSnapshot") or ""),
        str(data.get("photoUrl") or ""),
        str(data.get("photoProvider") or ""),
        data.get("workOrderCreated") is True,
        data.get("workCompleted") is True,
        str(data.get("status") or "open"),
        iso_utc(data.get("workOrderCreatedAt")),
        str(data.get("workOrderCreatedByNameSnapshot") or ""),
        iso_utc(data.get("workCompletedAt")),
        str(data.get("workCompletedByNameSnapshot") or ""),
        str(data.get("notes") or ""),
        str(data.get("appVersion") or ""),
        str(data.get("platform") or ""),
        int(data.get("schemaVersion") or 1),
        str(data.get("source") or "manual"),
        str(data.get("updatedByUid") or ""),
    ]


def delivery_status(payload: dict[str, Any] | None) -> str:
    if not payload:
        return ""
    delivery = payload.get("delivery")
    return str(delivery.get("status") or "") if isinstance(delivery, dict) else ""


def acknowledged_cursor_utc(payload: dict[str, Any] | None) -> datetime | None:
    if delivery_status(payload) != "acknowledged":
        return None
    delivery = payload.get("delivery")
    if not isinstance(delivery, dict):
        return None
    return as_datetime(delivery.get("cursorEndUtc"))


def build_payload(
    documents: list[tuple[str, dict[str, Any]]],
    *,
    cursor_start_utc: datetime | None = None,
) -> dict[str, Any]:
    ordered = sorted(
        documents,
        key=lambda item: (
            as_datetime(item[1].get("updatedAt"))
            or as_datetime(item[1].get("createdAt"))
            or datetime.min.replace(tzinfo=timezone.utc),
            item[0],
        ),
    )
    rows = [report_row(document_id, data) for document_id, data in ordered]
    cursor_end = cursor_start_utc
    if ordered:
        cursor_end = max(
            as_datetime(data.get("updatedAt"))
            or as_datetime(data.get("createdAt"))
            or datetime.min.replace(tzinfo=timezone.utc)
            for _, data in ordered
        )
    generated_at = datetime.now(timezone.utc)
    return {
        "schemaVersion": PAYLOAD_SCHEMA_VERSION,
        "collection": COLLECTION_NAME,
        "generatedAtUtc": generated_at.isoformat(),
        "timezone": "America/Guayaquil",
        "delivery": {
            "status": "ready",
            "batchId": f"leaks-{generated_at.strftime('%Y%m%dT%H%M%S%fZ')}",
            "cursorStartUtc": cursor_start_utc.isoformat()
            if cursor_start_utc
            else "",
            "cursorEndUtc": cursor_end.isoformat() if cursor_end else "",
            "rowCount": len(rows),
        },
        "dataset": {"columns": COLUMNS, "rows": rows},
    }


def load_github_issue_payload() -> dict[str, Any] | None:
    import requests

    repository = os.environ["EE_DATA_REPOSITORY"].strip()
    issue_number = int(os.environ.get("EE_LEAK_ISSUE_NUMBER", "2"))
    token = os.environ["EE_DATA_REPO_TOKEN"].strip()
    response = requests.get(
        f"https://api.github.com/repos/{repository}/issues/{issue_number}",
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
        },
        timeout=60,
    )
    response.raise_for_status()
    body = response.json().get("body") or ""
    try:
        parsed = json.loads(body)
        return parsed if isinstance(parsed, dict) else None
    except json.JSONDecodeError:
        return None


def load_firestore_reports(
    *, changed_since_utc: datetime | None
) -> list[tuple[str, dict[str, Any]]]:
    import firebase_admin
    from firebase_admin import credentials, firestore
    from google.cloud.firestore_v1.base_query import FieldFilter

    service_account = json.loads(os.environ["FIREBASE_SERVICE_ACCOUNT_JSON"])
    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.Certificate(service_account))
    query = firestore.client().collection(COLLECTION_NAME).order_by("updatedAt")
    if changed_since_utc is not None:
        query = query.where(
            filter=FieldFilter("updatedAt", ">", changed_since_utc)
        )
    max_rows = int(os.environ.get("EE_LEAK_MAX_ROWS", "50"))
    return [
        (snapshot.id, snapshot.to_dict() or {})
        for snapshot in query.limit(max_rows).stream()
    ]


def publish_payload_to_github_issue(payload: dict[str, Any]) -> None:
    import requests

    repository = os.environ["EE_DATA_REPOSITORY"].strip()
    issue_number = int(os.environ.get("EE_LEAK_ISSUE_NUMBER", "2"))
    token = os.environ["EE_DATA_REPO_TOKEN"].strip()
    body = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    max_chars = int(os.environ.get("EE_DATA_ISSUE_MAX_CHARS", "60000"))
    if len(body) > max_chars:
        raise ValueError(
            "El lote de fugas supera el limite seguro del issue: "
            f"{len(body)} > {max_chars} caracteres"
        )
    response = requests.patch(
        f"https://api.github.com/repos/{repository}/issues/{issue_number}",
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
        },
        json={"body": body},
        timeout=60,
    )
    response.raise_for_status()


def main() -> None:
    current_payload = load_github_issue_payload()
    if delivery_status(current_payload) == "ready":
        print("Existe un lote de fugas pendiente; no se consulto Firestore.")
        return
    cursor = acknowledged_cursor_utc(current_payload)
    documents = load_firestore_reports(changed_since_utc=cursor)
    if not documents:
        print("No hay reportes de fugas nuevos o actualizados.")
        return
    payload = build_payload(documents, cursor_start_utc=cursor)
    publish_payload_to_github_issue(payload)
    print(f"Lote de fugas publicado: {len(documents)} fila(s).")


if __name__ == "__main__":
    main()
