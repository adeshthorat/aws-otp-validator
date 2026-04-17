import json
import base64
import os
import re
from typing import Any, Dict
import boto3
import logging

from otp import constant_time_equals, current_epoch_seconds, is_valid_email, json_response, normalize_email, otp_hmac_sha256_hex

logger = logging.getLogger()
logger.setLevel(logging.INFO)

_dynamodb = boto3.resource("dynamodb")

_OTP_RE = re.compile(r"^\d{6}$")


def _parse_body(event: Dict[str, Any]) -> Dict[str, Any]:
    logger.info(f"Event structure: {list(event.keys())}")
    
    # Check if email and otp are directly in the event (direct Lambda invocation)
    if "email" in event and "otp" in event:
        logger.info("Parameters found directly in event")
        return {
            "email": event.get("email", ""),
            "otp": event.get("otp", "")
        }
    
    # Otherwise, try to parse from body (API Gateway)
    raw_body = event.get("body")
    logger.info(f"Raw body type: {type(raw_body)}, value: {raw_body}")
    
    if raw_body is None:
        logger.warning("Body is None, returning empty dict")
        return {}
    if isinstance(raw_body, str):
        is_base64 = bool(event.get("isBase64Encoded"))
        logger.info(f"Body is string, isBase64Encoded: {is_base64}")
        if is_base64:
            decoded = base64.b64decode(raw_body).decode("utf-8")
            result = json.loads(decoded) if decoded else {}
        else:
            result = json.loads(raw_body) if raw_body else {}
        logger.info(f"Parsed body: {result}")
        return result
    if isinstance(raw_body, dict):
        logger.info(f"Body is already dict: {raw_body}")
        return raw_body
    logger.warning(f"Unexpected body type: {type(raw_body)}")
    return {}


def lambda_handler(event, context):
    try:
        logger.info(f"Verify OTP request received: {json.dumps(event)}")
        
        body = _parse_body(event)
        email = body.get("email", "").strip()
        otp = body.get("otp", "").strip()

        # Validate email
        if not isinstance(email, str) or not is_valid_email(email):
            logger.warning(f"Invalid email format: {email}")
            return json_response(400, {"message": "Invalid email"})

        # Validate OTP format
        if not isinstance(otp, str) or not _OTP_RE.match(otp):
            logger.warning(f"Invalid OTP format: {otp}")
            return json_response(400, {"message": "Invalid OTP format"})

        email_norm = normalize_email(email)
        logger.info(f"Normalized email: {email_norm}")

        otp_ttl_seconds = int(os.environ.get("OTP_TTL_SECONDS", "300"))
        otp_hash_key = os.environ.get("OTP_HASH_KEY")
        if not otp_hash_key:
            logger.error("OTP_HASH_KEY environment variable not set")
            return json_response(500, {"message": "Server configuration error"})

        otp_table_name = os.environ.get("OTP_TABLE_NAME")
        if not otp_table_name:
            logger.error("OTP_TABLE_NAME environment variable not set")
            return json_response(500, {"message": "Server configuration error"})

        logger.info(f"Using OTP table: {otp_table_name}")
        table = _dynamodb.Table(otp_table_name)
        result = table.get_item(Key={"email": email_norm})
        item = result.get("Item")

        # Treat missing records as invalid OTP
        if not item:
            logger.warning(f"No OTP record found for email: {email_norm}")
            return json_response(401, {"message": "Invalid or expired OTP"})

        logger.info(f"OTP record found for email: {email_norm}")

        # Check if OTP has expired
        created_at = int(item.get("createdAt", 0))
        if created_at <= 0 or current_epoch_seconds() > created_at + otp_ttl_seconds:
            logger.warning(f"OTP expired for email: {email_norm}")
            return json_response(401, {"message": "Invalid or expired OTP"})

        # Verify OTP hash
        expected_hash = otp_hmac_sha256_hex(hash_key=otp_hash_key, email=email_norm, otp=otp)
        actual_hash = item.get("otpHash")
        if not constant_time_equals(actual_hash, expected_hash):
            logger.warning(f"OTP hash mismatch for email: {email_norm}")
            return json_response(401, {"message": "Invalid or expired OTP"})

        logger.info(f"OTP verified successfully for email: {email_norm}")

        # Extract user details before deletion
        user_name = item.get("name", "User")
        user_city = item.get("city", "")
        timestamp = item.get("timestamp", "")

        # OTP verified successfully; remove the record
        table.delete_item(Key={"email": email_norm})
        logger.info(f"OTP record deleted for email: {email_norm}")

        return json_response(200, {
            "status": "Success",
            "message": "OTP verified successfully",
            "user": {
                "email": email_norm,
                "name": user_name,
                "city": user_city,
                "timestamp": timestamp,
            },
        })
    
    except Exception as e:
        logger.error(f"Unexpected error in verify OTP: {str(e)}", exc_info=True)
        return json_response(500, {"message": "Internal server error"})

