output "rest_api_id" {
  description = "ID of the REST API"
  value       = aws_api_gateway_rest_api.this.id
}

output "execution_arn" {
  description = "Execution ARN of the REST API"
  value       = aws_api_gateway_rest_api.this.execution_arn
}

output "stage_invoke_url" {
  description = "Invoke URL of the deployed API Gateway stage"
  value       = "${aws_api_gateway_deployment.this.invoke_url}${var.stage_name}"
}
