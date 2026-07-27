from dataclasses import dataclass

import httpx
from firebase_admin import auth as firebase_auth
from firebase_admin import firestore as firebase_firestore
from fastapi import HTTPException, Request, status
from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer

from .config import Settings, get_settings
from .firebase import get_firestore


SESSION_COOKIE = "ee_admin_session"
SESSION_MAX_AGE_SECONDS = 8 * 60 * 60


@dataclass(frozen=True)
class AdminIdentity:
    uid: str
    display_name: str
    role: str = "admin"


def operator_email(national_id: str) -> str:
    return f"operator-{national_id.strip()}@eficiencia-energetica-ee.app"


def firebase_password(pin: str) -> str:
    return f"Ee:{pin}"


def _serializer(settings: Settings) -> URLSafeTimedSerializer:
    return URLSafeTimedSerializer(settings.dashboard_session_secret, salt="ee-admin-v1")


def create_session_token(identity: AdminIdentity, settings: Settings) -> str:
    return _serializer(settings).dumps(
        {"uid": identity.uid, "name": identity.display_name, "role": identity.role}
    )


def decode_session_token(token: str, settings: Settings) -> AdminIdentity:
    payload = _serializer(settings).loads(token, max_age=SESSION_MAX_AGE_SECONDS)
    if payload.get("role") != "admin":
        raise BadSignature("Admin role required")
    return AdminIdentity(
        uid=str(payload["uid"]),
        display_name=str(payload.get("name") or "Administrador"),
    )


def authenticate_admin(national_id: str, pin: str) -> AdminIdentity | None:
    settings = get_settings()
    settings.validate_runtime_secrets()
    if not national_id.isdigit() or len(national_id) != 10:
        return None
    if not pin.isdigit() or not 4 <= len(pin) <= 6:
        return None

    try:
        response = httpx.post(
            "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword",
            params={"key": settings.firebase_web_api_key},
            json={
                "email": operator_email(national_id),
                "password": firebase_password(pin),
                "returnSecureToken": True,
            },
            timeout=12,
        )
    except httpx.HTTPError:
        return None
    if response.status_code != 200:
        return None
    try:
        id_token = str(response.json().get("idToken") or "")
        decoded = firebase_auth.verify_id_token(id_token, check_revoked=True)
    except (ValueError, firebase_auth.InvalidIdTokenError, firebase_auth.RevokedIdTokenError):
        return None

    uid = str(decoded.get("uid") or "")
    db = get_firestore()
    profile = db.collection("users").document(uid).get()
    profile_data = profile.to_dict() or {}
    if not profile.exists or profile_data.get("active") is not True:
        return None
    if profile_data.get("role") != "admin":
        return None
    db.collection("audit_logs").add(
        {
            "eventType": "dashboard_admin_login",
            "actorUid": uid,
            "actorRole": "admin",
            "targetCollection": "users",
            "targetDocumentId": uid,
            "occurredAt": firebase_firestore.SERVER_TIMESTAMP,
            "platform": "web",
            "appVersion": "energy_dashboard",
            "metadata": {},
        }
    )
    return AdminIdentity(
        uid=uid,
        display_name=str(profile_data.get("displayName") or "Administrador"),
    )


def require_admin(request: Request) -> AdminIdentity:
    settings = get_settings()
    token = request.cookies.get(SESSION_COOKIE, "")
    try:
        identity = decode_session_token(token, settings)
    except (BadSignature, SignatureExpired, KeyError):
        raise HTTPException(
            status_code=status.HTTP_303_SEE_OTHER,
            headers={"Location": "/login"},
        )

    profile = (
        get_firestore().collection("users").document(identity.uid).get()
    )
    data = profile.to_dict() or {}
    if not profile.exists or data.get("active") is not True or data.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_303_SEE_OTHER,
            headers={"Location": "/login"},
        )
    return identity
