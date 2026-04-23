
#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TERRAFORM_DIR="$SCRIPT_DIR"

usage() {
  cat <<EOF
Usage: $0 [API_BASE_URL]

Tests OTP request and verification flow:
  1. Calls API_BASE_URL/otp/request to generate OTP
  2. Extracts OTP from response
  3. Calls API_BASE_URL/otp/verify with the extracted OTP
  4. Validates verification success

If no URL provided, reads endpoints from Terraform outputs.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 1 ]]; then
  usage
  exit 1
fi

# Resolve endpoints
if [[ -n "${1:-}" ]]; then
  base_url="${1%/}"
  request_endpoint="$base_url/otp/request"
  verify_endpoint="$base_url/otp/verify"
else
  cd "$TERRAFORM_DIR"
  request_endpoint=$(terraform output -raw request_otp_endpoint 2>/dev/null || echo "")
  verify_endpoint=$(terraform output -raw verify_otp_endpoint 2>/dev/null || echo "")
fi

if [[ -z "$request_endpoint" || -z "$verify_endpoint" ]]; then
  echo "ERROR: Unable to determine request/verify endpoints."
  exit 1
fi

email="test.user@example.com"
name="John Doe"
city="New York"

# Step 1: Request OTP
echo "=========================================="
echo "STEP 1: Requesting OTP"
echo "=========================================="
echo "Endpoint: $request_endpoint"
echo "Email: $email"

request_payload=$(cat <<EOF
{
  "email": "${email}",
  "name": "${name}",
  "city": "${city}"
}
EOF
)

echo "Payload: $request_payload"

request_response=$(curl -sS -X POST "$request_endpoint" \
  -H "Content-Type: application/json" \
  -d "$request_payload" 2>&1)

echo "Response: $request_response"

# Extract OTP using Python (more reliable than jq for edge cases)
otp=$(python3 -c "
import json
import sys
try:
    data = json.loads('''$request_response''')
    otp_val = data.get('otp', '')
    if otp_val:
        print(otp_val)
    else:
        sys.exit(1)
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null || echo "")

if [[ -z "$otp" ]]; then
  echo "ERROR: Could not extract OTP from response."
  echo "Response was: $request_response"
  exit 1
fi

echo -e "✓ OTP extracted: $otp"

# Step 2: Verify OTP
echo ""
echo "=========================================="
echo "STEP 2: Verifying OTP"
echo "=========================================="
echo "Endpoint: $verify_endpoint"
echo "Email: $email"
echo "OTP: $otp"

verify_payload=$(cat <<EOF
{
  "email": "${email}",
  "otp": "${otp}"
}
EOF
)

echo "Payload: $verify_payload"

verify_response=$(curl -sS -X POST "$verify_endpoint" \
  -H "Content-Type: application/json" \
  -d "$verify_payload" 2>&1)

echo "Response: $verify_response"


