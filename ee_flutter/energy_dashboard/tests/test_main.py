import pytest
from fastapi import HTTPException
from starlette.requests import Request

from app.auth import require_admin
from app.main import health, templates


def test_health_is_available():
    assert health() == {"status": "ok"}


def test_dashboard_requires_admin_session():
    request = Request({"type": "http", "headers": [], "method": "GET", "path": "/"})
    with pytest.raises(HTTPException) as error:
        require_admin(request)
    assert error.value.status_code == 303
    assert error.value.headers == {"Location": "/login"}


def test_templates_compile():
    templates.env.get_template("base.html")
    templates.env.get_template("login.html")
    templates.env.get_template("dashboard.html")
