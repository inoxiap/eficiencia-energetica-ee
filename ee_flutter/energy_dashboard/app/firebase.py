import os
from functools import lru_cache

import firebase_admin
from firebase_admin import firestore
from google.auth.credentials import AnonymousCredentials
from google.cloud import firestore as google_firestore

from .config import get_settings


@lru_cache
def get_firestore():
    settings = get_settings()
    if settings.firestore_emulator_host:
        os.environ["FIRESTORE_EMULATOR_HOST"] = settings.firestore_emulator_host
        return google_firestore.Client(
            project=settings.firebase_project_id,
            credentials=AnonymousCredentials(),
        )
    if not firebase_admin._apps:
        firebase_admin.initialize_app(options={"projectId": settings.firebase_project_id})
    return firestore.client()
