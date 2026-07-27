from app.auth import (
    AdminIdentity,
    create_session_token,
    decode_session_token,
    firebase_password,
    operator_email,
)
from app.config import Settings


def settings():
    return Settings(
        firebase_web_api_key="k" * 32,
        dashboard_session_secret="s" * 32,
    )


def test_operator_credentials_match_flutter_mapping():
    assert operator_email("1710034065") == (
        "operator-1710034065@eficiencia-energetica-ee.app"
    )
    assert firebase_password("1411") == "Ee:1411"


def test_signed_admin_session_round_trip():
    identity = AdminIdentity(uid="admin-1", display_name="Admin")
    token = create_session_token(identity, settings())
    decoded = decode_session_token(token, settings())
    assert decoded.uid == "admin-1"
    assert decoded.role == "admin"
