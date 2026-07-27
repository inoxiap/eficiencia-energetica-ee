import csv
import io
import json
from datetime import date, datetime, time, timedelta, timezone
from pathlib import Path
from typing import Annotated

from fastapi import Depends, FastAPI, Form, Query, Request
from fastapi.responses import HTMLResponse, RedirectResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from .analytics import build_dashboard, timestamp
from .auth import (
    SESSION_COOKIE,
    SESSION_MAX_AGE_SECONDS,
    AdminIdentity,
    authenticate_admin,
    create_session_token,
    require_admin,
)
from .config import get_settings
from .queries import DashboardFilters, MODULE_COLLECTIONS, iter_module_records, load_filtered_records


BASE_DIR = Path(__file__).resolve().parent
app = FastAPI(title="Eficiencia Energetica EE - Dashboard")
app.mount("/static", StaticFiles(directory=BASE_DIR / "static"), name="static")
templates = Jinja2Templates(directory=BASE_DIR / "templates")


def local_range(start_date: date, end_date: date) -> tuple[datetime, datetime]:
    zone = get_settings().timezone
    start = datetime.combine(start_date, time.min, tzinfo=zone).astimezone(timezone.utc)
    end = datetime.combine(end_date, time.max, tzinfo=zone).astimezone(timezone.utc)
    return start, end


def filters_from_query(
    start_date: date,
    end_date: date,
    section_id: str,
    equipment: str,
    user_uid: str,
    module: str,
    boiler_id: str,
    grouping: str,
) -> DashboardFilters:
    start, end = local_range(start_date, end_date)
    safe_module = module if module in {"all", *MODULE_COLLECTIONS.keys()} else "all"
    safe_grouping = grouping if grouping in {"hour", "day", "week", "month"} else "day"
    return DashboardFilters(
        start=start,
        end=end,
        section_id=section_id.strip(),
        equipment=equipment.strip(),
        user_uid=user_uid.strip(),
        module=safe_module,
        boiler_id=boiler_id.strip(),
        grouping=safe_grouping,
    )


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/login", response_class=HTMLResponse)
def login_page(request: Request):
    return templates.TemplateResponse(
        request=request,
        name="login.html",
        context={"error": ""},
    )


@app.post("/login", response_class=HTMLResponse)
def login(
    request: Request,
    national_id: Annotated[str, Form()],
    pin: Annotated[str, Form()],
):
    identity = authenticate_admin(national_id.strip(), pin)
    if identity is None:
        return templates.TemplateResponse(
            request=request,
            name="login.html",
            context={"error": "Credenciales incorrectas o usuario sin rol administrador."},
            status_code=401,
        )
    settings = get_settings()
    token = create_session_token(identity, settings)
    response = RedirectResponse("/", status_code=303)
    response.set_cookie(
        SESSION_COOKIE,
        token,
        max_age=SESSION_MAX_AGE_SECONDS,
        httponly=True,
        secure=settings.session_cookie_secure,
        samesite="lax",
    )
    return response


@app.post("/logout")
def logout():
    response = RedirectResponse("/login", status_code=303)
    response.delete_cookie(SESSION_COOKIE)
    return response


@app.get("/", response_class=HTMLResponse)
def dashboard(
    request: Request,
    admin: Annotated[AdminIdentity, Depends(require_admin)],
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    section_id: str = "",
    equipment: str = "",
    user_uid: str = "",
    module: str = "all",
    boiler_id: str = "",
    grouping: str = "day",
    page: int = Query(default=1, ge=1),
):
    today = datetime.now(get_settings().timezone).date()
    selected_end = end_date or today
    selected_start = start_date or selected_end - timedelta(days=30)
    filters = filters_from_query(
        selected_start,
        selected_end,
        section_id,
        equipment,
        user_uid,
        module,
        boiler_id,
        grouping,
    )
    records = load_filtered_records(filters)
    data = build_dashboard(records, grouping, filters.start, filters.end)
    recent = []
    for module_name, module_records in records.items():
        for record in module_records:
            recent.append(
                {
                    "module": module_name,
                    "date": timestamp(record.get("createdAt") or record.get("recordedAt")),
                    "section": record.get("sectionNameSnapshot") or record.get("section") or "",
                    "equipment": record.get("equipmentName") or record.get("boilerName") or record.get("pumpTag") or "",
                    "user": record.get("createdByNameSnapshot") or "Historico",
                    "status": record.get("status") or "historico",
                }
            )
    recent.sort(key=lambda item: item["date"] or datetime.min.replace(tzinfo=timezone.utc), reverse=True)
    page_size = 25
    start_index = (page - 1) * page_size
    page_records = recent[start_index : start_index + page_size]

    return templates.TemplateResponse(
        request=request,
        name="dashboard.html",
        context={
            "admin": admin,
            "filters": filters,
            "start_date": selected_start.isoformat(),
            "end_date": selected_end.isoformat(),
            "data": data,
            "data_json": json.dumps(data, default=str),
            "records": page_records,
            "page": page,
            "has_previous": page > 1,
            "has_next": start_index + page_size < len(recent),
            "last_updated": datetime.now(get_settings().timezone),
        },
    )


@app.get("/export.csv")
def export_csv(
    admin: Annotated[AdminIdentity, Depends(require_admin)],
    start_date: date,
    end_date: date,
    section_id: str = "",
    equipment: str = "",
    user_uid: str = "",
    module: str = "all",
    boiler_id: str = "",
    grouping: str = "day",
):
    del admin, grouping
    filters = filters_from_query(
        start_date,
        end_date,
        section_id,
        equipment,
        user_uid,
        module,
        boiler_id,
        "day",
    )
    modules = MODULE_COLLECTIONS.keys() if filters.module == "all" else [filters.module]

    def rows():
        buffer = io.StringIO()
        writer = csv.writer(buffer)
        writer.writerow(
            [
                "module",
                "documentId",
                "createdAt",
                "sectionId",
                "equipment",
                "createdByUid",
                "status",
                "dataJson",
            ]
        )
        yield buffer.getvalue()
        buffer.seek(0)
        buffer.truncate(0)
        for module_name in modules:
            for record in iter_module_records(module_name, filters):
                writer.writerow(
                    [
                        module_name,
                        record.get("_documentId"),
                        record.get("createdAt") or record.get("recordedAt"),
                        record.get("sectionId"),
                        record.get("equipmentName") or record.get("boilerName") or record.get("pumpTag"),
                        record.get("createdByUid"),
                        record.get("status"),
                        json.dumps(record, default=str, ensure_ascii=False),
                    ]
                )
                yield buffer.getvalue()
                buffer.seek(0)
                buffer.truncate(0)

    filename = "eficiencia_energetica_" + start_date.isoformat() + "_" + end_date.isoformat() + ".csv"
    return StreamingResponse(
        rows(),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": 'attachment; filename="' + filename + '"'},
    )
