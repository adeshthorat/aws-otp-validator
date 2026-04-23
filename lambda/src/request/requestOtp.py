import json
import base64
import os
from typing import Any, Dict
import boto3
import logging

from otp import (
    current_epoch_seconds,
    generate_otp,
    generate_unique_hash,
    get_timestamp_formatted,
    is_valid_email,
    json_response,
    normalize_email,
    otp_hmac_sha256_hex,
)

logger = logging.getLogger()
logger.setLevel(logging.INFO)

_dynamodb = boto3.resource("dynamodb")


def _parse_body(event: Dict[str, Any]) -> Dict[str, Any]:
    # Check if parameters are directly in the event (direct Lambda invocation)
    if "email" in event and ("name" in event or "city" in event):
        return {
            "email": event.get("email", ""),
            "name": event.get("name", ""),
            "city": event.get("city", "")
        }
    
    # Otherwise, try to parse from body (API Gateway)
    raw_body = event.get("body")
    if raw_body is None:
        return {}
    if isinstance(raw_body, str):
        is_base64 = bool(event.get("isBase64Encoded"))
        if is_base64:
            decoded = base64.b64decode(raw_body).decode("utf-8")
            return json.loads(decoded) if decoded else {}
        return json.loads(raw_body) if raw_body else {}
    if isinstance(raw_body, dict):
        return raw_body
    return {}


def lambda_handler(event, context):
    body = _parse_body(event)
    email = body.get("email", "").strip()
    name = body.get("name", "").strip()
    city = body.get("city", "").strip()

    # Validate email
    if not isinstance(email, str) or not email or not is_valid_email(email):
        return json_response(400, {"message": "Invalid email"})

    # Validate name and city
    if not isinstance(name, str) or not name:
        return json_response(400, {"message": "Name is required"})
    if not isinstance(city, str) or not city:
        return json_response(400, {"message": "City is required"})

    email_norm = normalize_email(email)

    otp_ttl_seconds = int(os.environ.get("OTP_TTL_SECONDS", "300"))
    otp_hash_key = os.environ.get("OTP_HASH_KEY")
    if not otp_hash_key:
        return json_response(500, {"message": "Server error"})

    otp_table_name = os.environ.get("OTP_TABLE_NAME")
    if not otp_table_name:
        return json_response(500, {"message": "Server error"})

    # Generate OTP, unique hash, and formatted timestamp
    otp = generate_otp(6)
    unique_hash = generate_unique_hash()
    timestamp_formatted = get_timestamp_formatted()
    now = current_epoch_seconds()
    ttl = now + otp_ttl_seconds
    otp_hash = otp_hmac_sha256_hex(hash_key=otp_hash_key, email=email_norm, otp=otp)

    # Store OTP data with user details in DynamoDB
    table = _dynamodb.Table(otp_table_name)
    table.put_item(
        Item={
            "email": email_norm,
            "uniqueHash": unique_hash,
            "name": name,
            "city": city,
            "otp": otp,
            "timestamp": timestamp_formatted,
            "otpHash": otp_hash,
            "createdAt": now,
            "ttl": ttl,
        }
    )

    return json_response(200, {
        "status": "OTP_SENT",
        "message": "OTP generated and stored successfully",
        "otp": otp,
        "uniqueHash": unique_hash,
        "expiresIn": f"{otp_ttl_seconds // 60} minutes",
    })

