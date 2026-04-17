# AWS OTP Auth Validator (Amplify + API Gateway + Lambda + DynamoDB + SES)

## What it does
1. User enters an email address.
2. `POST /otp/request` generates a secure OTP, stores only an HMAC hash in DynamoDB (with TTL), and emails the OTP via SES.
3. User submits the OTP to `POST /otp/verify`.
4. On success, the frontend redirects to a page showing **"OTP Verified Successfully"**.

## Backend (SAM / Python Lambda)
Files:
- `backend/template.yaml`
- `backend/src/requestOtp.py`
- `backend/src/verifyOtp.py`
- `backend/src/otp.py`

Prerequisites:
- Create/verify an SES email identity for `SesSourceEmail` (the "From" address).
- Ensure the Lambda execution role can send email (`ses:SendEmail`) and read/write the DynamoDB table.

Deploy (from the `backend/` directory):
- `sam build`
- `sam deploy --guided`

During deployment, provide:
- `SesSourceEmail` (must be SES-verified)
- `OtpHashKey` (generate a strong random secret; keep it private)
- `OtpTtlSeconds` (default: 300)

After deployment, copy `OtpApiBaseUrl` from the stack outputs.

## Frontend (React on Amplify Hosting)
Files:
- `frontend/amplify.yml`
- `frontend/src/amplifyClient.ts` (uses `VITE_OTP_API_BASE_URL`)
- `frontend/src/pages/RequestOtp.tsx`
- `frontend/src/pages/VerifyOtp.tsx`
- `frontend/src/pages/Verified.tsx`

Deploy the React app to Amplify Hosting, and set:
- `VITE_OTP_API_BASE_URL` = the `OtpApiBaseUrl` output from the SAM stack

## Notes
- OTPs are never stored in plaintext. DynamoDB stores an HMAC hash + timestamps, and TTL auto-expires items.
- `verifyOtp` enforces expiry server-side even though DynamoDB TTL is eventual.

# aws-otp-validator
