# AWS OTP Auth Validator - Manual Deployment Guide

This guide walks you through manually deploying the OTP authentication application on AWS using DynamoDB, Lambda, SES, and API Gateway.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Step 1: Setup IAM Role for Lambda](#step-1-setup-iam-role-for-lambda)
3. [Step 2: Setup DynamoDB Table](#step-2-setup-dynamodb-table)
4. [Step 3: Setup SES (Simple Email Service)](#step-3-setup-ses-simple-email-service)
5. [Step 4: Create Lambda Functions](#step-4-create-lambda-functions)
6. [Step 5: Setup API Gateway](#step-5-setup-api-gateway)
7. [Step 6: Deploy Frontend](#step-6-deploy-frontend)
8. [Testing](#testing)
9. [Cleanup](#cleanup)

---

## Prerequisites

- AWS Account with sufficient permissions
- AWS CLI configured with credentials
- Python 3.11 runtime available
- Node.js and npm for frontend
- A verified SES email identity (for sending OTPs)

---

## Step 1: Setup IAM Role for Lambda

### 1.1 Create IAM Role

1. Go to **AWS Console** → **IAM** → **Roles**
2. Click **Create role**
3. Select **AWS service** → **Lambda**
4. Click **Next**

### 1.2 Attach Policies

Create inline policies for the role:

**Policy 1: DynamoDB Access**

1. Click **Create inline policy** → **JSON**
2. Paste the following:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/otp-codes-table"
    }
  ]
}
```

3. Click **Review policy** → Give it a name (e.g., `DynamoDBOtpTableAccess`)
4. Click **Create policy**

**Policy 2: SES Access**

1. Click **Create inline policy** → **JSON**
2. Paste the following:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ses:SendEmail"
      ],
      "Resource": "*"
    }
  ]
}
```

3. Click **Review policy** → Give it a name (e.g., `SESEmailAccess`)
4. Click **Create policy**

### 1.3 Complete Role Creation

1. Review and create the role (e.g., name it `OtpLambdaExecutionRole`)
2. Copy the **ARN** of this role (you'll need it later)

---

## Step 2: Setup DynamoDB Table

### 2.1 Create Table

1. Go to **AWS Console** → **DynamoDB** → **Tables**
2. Click **Create table**
3. Configure as follows:

| Setting | Value |
|---------|-------|
| Table name | `otp-codes-table` |
| Partition key | `email` (String) |
| Billing mode | **On-demand** (PAY_PER_REQUEST) |
| Enable TTL | ✓ Yes |
| TTL attribute name | `ttl` |

4. Click **Create table**

### 2.2 Enable TTL

1. Wait for table creation to complete
2. Click on the table name
3. Go to **TTL** (or **Settings** tab)
4. Verify TTL is enabled on the `ttl` attribute (should be auto-set)

The table structure:
```
Partition Key: email (String)
Attributes:
  - email: String (PK)
  - otpHash: String (HMAC-SHA256 hash of OTP)
  - createdAt: Number (Unix timestamp)
  - ttl: Number (Unix timestamp for expiry)
```

---

## Step 3: Setup SES (Simple Email Service)

### 3.1 Verify Email Identity

1. Go to **AWS Console** → **SES (Simple Email Service)** → **Verified identities**
2. Click **Create identity**
3. Select **Email address**
4. Enter your email (e.g., `noreply@yourdomain.com` or your personal email)
5. Click **Create identity**
6. You'll receive a verification email - **click the verification link**

**Note:** In SES Sandbox mode, you can only send to verified email addresses. To send to any email, request production access.

### 3.2 Get SES Region

1. Note the **AWS Region** you're using (e.g., `us-east-1`)
2. Ensure all resources are created in the same region

---

## Step 4: Create Lambda Functions

### 4.1 Prepare Lambda Code

**Create two Lambda functions:**
1. `RequestOtpFunction` - Generates and sends OTP
2. `VerifyOtpFunction` - Validates OTP

#### Function 1: RequestOtpFunction

1. Go to **AWS Console** → **Lambda** → **Functions**
2. Click **Create function**
3. Configure:
   - **Function name:** `otp-request-function`
   - **Runtime:** Python 3.11
   - **Role:** Select the IAM role created in Step 1
4. Click **Create function**

5. In the **Code source** section, create the following files:

**File 1: `lambda_function.py`**

```python
import json
import base64
import os
from typing import Any, Dict
import boto3
import hmac
import hashlib
import secrets
import re
import time

_dynamodb = boto3.resource("dynamodb")
_ses = boto3.client("ses")

_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

def normalize_email(email: str) -> str:
    return email.strip().lower()

def is_valid_email(email: str) -> bool:
    return bool(_EMAIL_RE.match(email))

def current_epoch_seconds() -> int:
    return int(time.time())

def generate_otp(n_digits: int = 6) -> str:
    if n_digits <= 0:
        raise ValueError("n_digits must be positive")
    max_value = 10**n_digits
    otp_int = secrets.randbelow(max_value)
    return str(otp_int).zfill(n_digits)

def otp_hmac_sha256_hex(*, hash_key: str, email: str, otp: str) -> str:
    msg = f"{email}:{otp}".encode("utf-8")
    key = hash_key.encode("utf-8")
    return hmac.new(key, msg, hashlib.sha256).hexdigest()

def json_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
        "body": json.dumps(body),
    }

def _parse_body(event: Dict[str, Any]) -> Dict[str, Any]:
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
    email = body.get("email", "")

    if not isinstance(email, str) or not email.strip() or not is_valid_email(email):
        return json_response(400, {"message": "Invalid email"})

    email_norm = normalize_email(email)

    otp_ttl_seconds = int(os.environ.get("OTP_TTL_SECONDS", "300"))
    otp_hash_key = os.environ.get("OTP_HASH_KEY")
    if not otp_hash_key:
        return json_response(500, {"message": "Server error"})

    otp_table_name = os.environ.get("OTP_TABLE_NAME")
    if not otp_table_name:
        return json_response(500, {"message": "Server error"})

    ses_source_email = os.environ.get("SES_SOURCE_EMAIL")
    if not ses_source_email:
        return json_response(500, {"message": "Server error"})

    otp = generate_otp(6)
    otp_hash = otp_hmac_sha256_hex(hash_key=otp_hash_key, email=email_norm, otp=otp)

    now = current_epoch_seconds()
    ttl = now + otp_ttl_seconds

    table = _dynamodb.Table(otp_table_name)
    table.put_item(
        Item={
            "email": email_norm,
            "otpHash": otp_hash,
            "createdAt": now,
            "ttl": ttl,
        }
    )

    try:
        _ses.send_email(
            Source=ses_source_email,
            Destination={"ToAddresses": [email_norm]},
            Message={
                "Subject": {"Data": "Your OTP Code"},
                "Body": {
                    "Text": {
                        "Data": (
                            f"Your OTP code is {otp}. "
                            f"It expires in {otp_ttl_seconds // 60} minutes."
                        )
                    }
                },
            },
        )
    except Exception as e:
        print(f"SES error: {str(e)}")
        return json_response(500, {"message": "Could not send OTP"})

    return json_response(200, {"status": "OTP_SENT"})
```

6. Click **Deploy**
7. Go to **Configuration** → **Environment variables**
8. Add the following:
   - `OTP_TABLE_NAME` = `otp-codes-table`
   - `OTP_TTL_SECONDS` = `300`
   - `SES_SOURCE_EMAIL` = Your verified SES email (from Step 3)
   - `OTP_HASH_KEY` = Generate a strong random secret (e.g., `openssl rand -hex 32`)

9. Click **Save**

#### Function 2: VerifyOtpFunction

1. Go to **AWS Console** → **Lambda** → **Functions**
2. Click **Create function**
3. Configure:
   - **Function name:** `otp-verify-function`
   - **Runtime:** Python 3.11
   - **Role:** Select the same IAM role
4. Click **Create function**

5. Paste the following code in the editor:

```python
import json
import base64
import os
import re
from typing import Any, Dict
import boto3
import hmac
import hashlib
import time

_dynamodb = boto3.resource("dynamodb")

_OTP_RE = re.compile(r"^\d{6}$")
_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

def normalize_email(email: str) -> str:
    return email.strip().lower()

def is_valid_email(email: str) -> bool:
    return bool(_EMAIL_RE.match(email))

def current_epoch_seconds() -> int:
    return int(time.time())

def otp_hmac_sha256_hex(*, hash_key: str, email: str, otp: str) -> str:
    msg = f"{email}:{otp}".encode("utf-8")
    key = hash_key.encode("utf-8")
    return hmac.new(key, msg, hashlib.sha256).hexdigest()

def constant_time_equals(a, b):
    if a is None:
        return False
    return hmac.compare_digest(a, b)

def json_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
        "body": json.dumps(body),
    }

def _parse_body(event: Dict[str, Any]) -> Dict[str, Any]:
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
    email = body.get("email", "")
    otp = body.get("otp", "")

    if not isinstance(email, str) or not is_valid_email(email):
        return json_response(400, {"message": "Invalid email"})
    if not isinstance(otp, str) or not _OTP_RE.match(otp):
        return json_response(400, {"message": "Invalid OTP"})

    email_norm = normalize_email(email)

    otp_ttl_seconds = int(os.environ.get("OTP_TTL_SECONDS", "300"))
    otp_hash_key = os.environ.get("OTP_HASH_KEY")
    if not otp_hash_key:
        return json_response(500, {"message": "Server error"})

    otp_table_name = os.environ.get("OTP_TABLE_NAME")
    if not otp_table_name:
        return json_response(500, {"message": "Server error"})

    table = _dynamodb.Table(otp_table_name)
    result = table.get_item(Key={"email": email_norm})
    item = result.get("Item")

    if not item:
        return json_response(401, {"message": "Invalid or expired OTP"})

    created_at = int(item.get("createdAt", 0))
    if created_at <= 0 or current_epoch_seconds() > created_at + otp_ttl_seconds:
        return json_response(401, {"message": "Invalid or expired OTP"})

    expected_hash = otp_hmac_sha256_hex(hash_key=otp_hash_key, email=email_norm, otp=otp)
    actual_hash = item.get("otpHash")
    if not constant_time_equals(actual_hash, expected_hash):
        return json_response(401, {"message": "Invalid or expired OTP"})

    table.delete_item(Key={"email": email_norm})
    return json_response(200, {"status": "VERIFIED"})
```

6. Click **Deploy**
7. Go to **Configuration** → **Environment variables**
8. Add the following:
   - `OTP_TABLE_NAME` = `otp-codes-table`
   - `OTP_TTL_SECONDS` = `300`
   - `OTP_HASH_KEY` = **Use the same value as RequestOtpFunction**

9. Click **Save**

---

## Step 5: Setup API Gateway

### 5.1 Create REST API

1. Go to **AWS Console** → **API Gateway**
2. Click **Create API**
3. Select **REST API** → Click **Build**
4. Configure:
   - **API name:** `otp-auth-api`
   - **Endpoint type:** Regional
5. Click **Create API**

### 5.2 Create Resources and Methods

**Create `/otp` Resource:**

1. In the API structure, right-click **/** (root)
2. Click **Create resource**
3. Configure:
   - **Resource name:** `otp`
   - **Resource path:** `/otp`
4. Click **Create resource**

**Create `/otp/request` Resource:**

1. Right-click the `/otp` resource
2. Click **Create resource**
3. Configure:
   - **Resource name:** `request`
   - **Resource path:** `/request`
4. Click **Create resource**

**Create `/otp/request` POST Method:**

1. Click the `/request` resource
2. Click **Create method** → **POST**
3. Configure:
   - **Integration type:** Lambda function
   - **Lambda function:** `otp-request-function`
4. Click **Create method**

**Setup CORS for POST /otp/request:**

1. Click **Enable CORS and replace existing CORS headers**
2. Ensure the following headers are checked:
   - `Content-Type`
   - `X-Amz-Date`
   - `Authorization`
3. Click **Save**

**Create `/otp/verify` Resource:**

1. Right-click the `/otp` resource
2. Click **Create resource**
3. Configure:
   - **Resource name:** `verify`
   - **Resource path:** `/verify`
4. Click **Create resource**

**Create `/otp/verify` POST Method:**

1. Click the `/verify` resource
2. Click **Create method** → **POST**
3. Configure:
   - **Integration type:** Lambda function
   - **Lambda function:** `otp-verify-function`
4. Click **Create method**

**Setup CORS for POST /otp/verify:**

1. Click **Enable CORS and replace existing CORS headers**
2. Ensure the same headers are checked
3. Click **Save**

### 5.3 Handle OPTIONS for CORS

1. Click the `/request` resource
2. Click **Create method** → **OPTIONS**
3. Configure:
   - **Integration type:** Mock
4. Click **Create method**
5. Repeat for the `/verify` resource

### 5.4 Deploy API

1. Click **Deploy API** (at top)
2. Configure:
   - **Stage:** Create a new stage called `Prod`
   - Click **Deploy**
3. Copy the **Invoke URL** (e.g., `https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/Prod`)
   - This is your `OtpApiBaseUrl` for the frontend

---

## Step 6: Deploy Frontend

### 6.1 Prepare Frontend

1. Navigate to the `frontend/` directory:
   ```bash
   cd frontend
   npm install
   ```

2. Create a `.env.production` file with:
   ```
   VITE_OTP_API_BASE_URL=https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/Prod
   VITE_AWS_REGION=us-east-1
   ```

   Replace the URL with your API Gateway URL from Step 5.4

### 6.2 Build Frontend

```bash
npm run build
```

This creates a `dist/` folder with production-ready files.

### 6.3 Deploy to AWS Amplify Hosting

#### Option A: Using AWS Amplify Console

1. Go to **AWS Console** → **Amplify Hosting**
2. Click **Create new app** → **Host web app**
3. Select your Git provider (GitHub, GitLab, etc.)
4. Connect your repository
5. Configure build settings:
   - **Build command:** `npm run build` (in the `frontend/` directory)
   - **Base directory:** `frontend`
   - **Build output directory:** `dist`
6. Add environment variables:
   - `VITE_OTP_API_BASE_URL` = Your API Gateway URL
   - `VITE_AWS_REGION` = Your AWS region
7. Click **Deploy**

#### Option B: Manual S3 + CloudFront Deployment

1. Create an S3 bucket (e.g., `otp-app-frontend-bucket`)
2. Enable **Static website hosting** in the bucket settings
3. Upload the contents of the `dist/` folder

   ```bash
   aws s3 sync dist/ s3://otp-app-frontend-bucket/ --delete
   ```

4. Create a CloudFront distribution:
   - **Origin domain:** Your S3 bucket
   - **Allow public access**
5. Access your app via the CloudFront URL

---

## Testing

### 6.1 Test Request OTP

```bash
curl -X POST https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/Prod/otp/request \
  -H "Content-Type: application/json" \
  -d '{"email": "your-email@example.com"}'
```

Expected response:
```json
{"status": "OTP_SENT"}
```

Check your email for the OTP code.

### 6.2 Test Verify OTP

```bash
curl -X POST https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/Prod/otp/verify \
  -H "Content-Type: application/json" \
  -d '{"email": "your-email@example.com", "otp": "123456"}'
```

Expected response (on success):
```json
{"status": "VERIFIED"}
```

### 6.3 Test in Browser

1. Navigate to your frontend URL
2. Enter your email address
3. Click **Request OTP**
4. Check your email for the OTP
5. Enter the OTP and click **Verify**
6. See the "OTP Verified Successfully" message

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Frontend (React)                         │
│          Deployed on: Amplify Hosting / S3 + CloudFront         │
│               (VITE_OTP_API_BASE_URL configured)                │
└────────────────────────────┬────────────────────────────────────┘
                             │
                    API calls (HTTP/HTTPS)
                             │
           ┌─────────────────▼──────────────────┐
           │      API Gateway (REST API)        │
           │  - POST /otp/request               │
           │  - POST /otp/verify                │
           │  - CORS enabled                    │
           └──────┬──────────────────┬──────────┘
                  │                  │
        ┌─────────▼────┐   ┌────────▼─────────┐
        │   Lambda      │   │   Lambda         │
        │   Request OTP │   │   Verify OTP     │
        └──────┬────────┘   └────────┬─────────┘
               │                     │
               └──────────┬──────────┘
                          │
        ┌─────────────────▼──────────────────┐
        │         DynamoDB Table             │
        │  - Partition Key: email            │
        │  - otpHash (HMAC-SHA256)           │
        │  - createdAt, ttl                  │
        │  - TTL auto-expiration enabled     │
        └──────────────────────────────────┘

        ┌──────────────────────────────────┐
        │   SES (Simple Email Service)     │
        │   - Verified email identity      │
        │   - Sends OTP emails             │
        └──────────────────────────────────┘
```

---

## Security Considerations

1. **OTP Hashing:** OTPs are never stored in plaintext. Only HMAC-SHA256 hashes are stored.
2. **Email Binding:** OTP hashes are bound to the user's email address to prevent hash reuse.
3. **Server-side Expiry:** Both DynamoDB TTL and server-side checks validate expiry.
4. **Constant-time Comparison:** Uses `hmac.compare_digest()` to prevent timing attacks.
5. **SES Verification:** Only verified email identities can send OTPs (in Sandbox mode).
6. **CORS:** API Gateway CORS is configured to allow frontend requests.

---

## Cost Optimization

- **DynamoDB:** On-demand billing (pay per request, no minimum)
- **Lambda:** Pay for invocations and execution time (generous free tier)
- **SES:** First 62,000 emails/month free (in Sandbox mode)
- **API Gateway:** 1M requests/month free (then $3.50 per million)
- **Amplify:** Build minutes and hosting bandwidth charged separately

---

## Cleanup

To avoid ongoing charges, delete resources in this order:

1. **Amplify App:** Go to Amplify → App settings → Delete app
2. **API Gateway:** Go to API Gateway → Select API → Delete API
3. **Lambda Functions:**
   - `otp-request-function`
   - `otp-verify-function`
4. **DynamoDB Table:** `otp-codes-table`
5. **IAM Role:** `OtpLambdaExecutionRole`

---

## Troubleshooting

### OTP Not Sent

- Verify SES identity is confirmed
- Check Lambda environment variables are set correctly
- Review CloudWatch Logs for Lambda errors:
  - Go to **CloudWatch** → **Logs** → **Log Groups** → `/aws/lambda/otp-request-function`

### "Invalid or expired OTP"

- Verify the OTP within 5 minutes (default TTL)
- Check that both Lambda functions use the same `OTP_HASH_KEY`
- Ensure email is normalized (lowercase)

### API Gateway CORS Errors

- Verify CORS headers are enabled on all methods
- Check Access-Control-Allow-Origin header is set to `*`
- Test with `curl -H "Origin: *"` to debug

### DynamoDB Errors

- Verify IAM role has DynamoDB permissions
- Confirm table name matches `OTP_TABLE_NAME` environment variable
- Check TTL is enabled on the table

---

## Next Steps

- Implement frontend authentication (sign-up/login)
- Add rate limiting to prevent brute force attacks
- Implement SMS OTP as an alternative to email
- Add multi-factor authentication (MFA) options
- Monitor CloudWatch logs and set up alarms
