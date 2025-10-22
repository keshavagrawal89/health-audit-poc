import uuid
from datetime import datetime

def new_event_id() -> str:
    """Generate a UUID v7 (time-ordered UUID)"""
    return str(uuid.uuid7())
