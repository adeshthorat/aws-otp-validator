# OTP Validator API Usage

## Overview
This Lambda-based OTP validation system stores user information with unique identifiers and validates OTPs through DynamoDB. **No external email service is used - OTP is returned directly in the API response.**

---

## 1. Request OTP Endpoint
**Endpoint:** `POST /otp/request`

**Request Body:**
```json
{
  "email": "user@example.com",
  "name": "John Doe",
  "city": "New York"
}
```

**Response (Success - 200):**
```json
{
  "status": "OTP_SENT",
  "message": "OTP generated and stored successfully",
  "otp": "123456",
  "uniqueHash": "a1b2c3d4e5f6g7h8",
  "expiresIn": "5 minutes"
}
```

**Response (Error - 400/500):**
```json
{
  "message": "Invalid email | Name is required | City is required | Server error"
}
```

**DynamoDB Storage:**
```
Item {
  email: "user@example.com" (Primary Key)
  uniqueHash: "a1b2c3d4e5f6g7h8" (16-char hexadecimal)
  name: "John Doe"
  city: "New York"
  timestamp: "16-04-2026 14:30:45" (dd-mm-yyyy HH:MM:SS format)
  otpHash: "hash_of_email_and_otp" (HMAC-SHA256)
  createdAt: 1713286245 (epoch seconds)
  ttl: 1713286545 (auto-deletion after 5 minutes by default)
}
```

---

## 2. Verify OTP Endpoint
**Endpoint:** `POST /otp/verify`

**Request Body:**
```json
{
  "email": "user@example.com",
  "otp": "123456"
}
```

**Response (Success - 200):**
```json
{
  "status": "Success",
  "message": "OTP verified successfully",
  "user": {
    "email": "user@example.com",
    "name": "John Doe",
    "city": "New York",
    "timestamp": "16-04-2026 14:30:45"
  }
}
```

**Response (Error - 401/400):**
```json
{
  "message": "Invalid or expired OTP | Invalid email | Invalid OTP format | Invalid unique hash"
}
```

---

## Key Features

✅ **User Information Storage**
- Email (normalized)
- Name
- City
- Timestamp in dd-mm-yyyy HH:MM:SS format

✅ **Security**
- OTP stored as HMAC-SHA256 hash (never plaintext)
- Constant-time comparison for hash verification
- Unique hash (16-char hex) per user request
- Automatic TTL-based expiration in DynamoDB

✅ **Validation**
- Email format validation
- OTP format validation (6 digits)
- Hash format validation
- Email and OTP binding to prevent cross-user attacks

✅ **Response**
- Returns "Success" status on successful verification
- User details returned on verification
- Record auto-deleted after successful verification
- OTP included in request response

✅ **Architecture**
- **Lambda**: Serverless compute (requestOtp, verifyOtp)
- **API Gateway**: RESTful endpoints for request/verify
- **DynamoDB**: Secure storage with TTL auto-expiration
- **No SES**: OTP delivered directly via API response

---

## Environment Variables Required

```
OTP_TABLE_NAME=<dynamodb-table-name>
OTP_TTL_SECONDS=300 (default: 5 minutes)
OTP_HASH_KEY=<secret-key-for-hmac>
```

---

## Example Workflow

1. **User requests OTP:**
   ```
   POST /otp/request
   {
     "email": "john@example.com",
     "name": "John Doe",
     "city": "New York"
   }
   ```
   Response includes `otp` and `uniqueHash`

2. **Frontend receives OTP** directly in response (no email sending)

3. **User verifies OTP:**
   ```
   POST /otp/verify
   {
     "email": "john@example.com",
     "otp": "123456"
   }
   ```
   Response: `{"status": "Success", "message": "OTP verified successfully", ...}`

4. **Record is automatically deleted** from DynamoDB after successful verification
