import json
import hashlib
import hmac
import re
import secrets
import time
import uuid
from datetime import datetime
from typing import Any, Dict, Optional


_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def normalize_email(email: str) -> str:
    # Basic normalization (avoid mismatches in DynamoDB keys).
    return email.strip().lower()


def is_valid_email(email: str) -> bool:
    return bool(_EMAIL_RE.match(email))


def current_epoch_seconds() -> int:
    return int(time.time())


def get_timestamp_formatted() -> str:
    """Return current timestamp in dd-mm-yyyy HH:MM:SS format."""
    return datetime.now().strftime("%d-%m-%Y %H:%M:%S")


def generate_unique_hash() -> str:
    """Generate a unique hash value for the user."""
    return hashlib.sha256(uuid.uuid4().bytes).hexdigest()[:16]


def generate_otp(n_digits: int = 6) -> str:
    if n_digits <= 0:
        raise ValueError("n_digits must be positive")
    max_value = 10**n_digits
    otp_int = secrets.randbelow(max_value)
    return str(otp_int).zfill(n_digits)


def otp_hmac_sha256_hex(*, hash_key: str, email: str, otp: str) -> str:
    """
    OTPs are stored as HMAC hashes (never plaintext).
    We bind the OTP to the user's email so the same OTP value doesn't
    share hashes across identities.
    """
    msg = f"{email}:{otp}".encode("utf-8")
    key = hash_key.encode("utf-8")
    return hmac.new(key, msg, hashlib.sha256).hexdigest()


def constant_time_equals(a: Optional[str], b: str) -> bool:
    if a is None:
        return False
    return hmac.compare_digest(a, b)


def json_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }

