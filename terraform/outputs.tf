output "api_gateway_invoke_url" {
  description = "The base URL for the API Gateway"
  value       = module.api_gateway.stage_invoke_url
}

output "request_otp_endpoint" {
  description = "Endpoint to request an OTP"
  value       = "${module.api_gateway.stage_invoke_url}/otp/request"
}

output "verify_otp_endpoint" {
  description = "Endpoint to verify an OTP"
  value       = "${module.api_gateway.stage_invoke_url}/otp/verify"
}

output "dynamo-db-table-name" {
  description = "Name of the DynamoDB table"
  value       = module.dynamodb.table_name  
}

output "iam-role" {
  description = "Lambda iam role"
  value = module.iam.role_arn
}