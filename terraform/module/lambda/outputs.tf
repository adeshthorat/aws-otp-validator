output "lambda_arn" {
  description = "The ARN of the lambda function"
  value       = aws_lambda_function.this.arn
}

output "lambda_name" {
  description = "The name of the lambda function"
  value       = aws_lambda_function.this.function_name
}

output "invoke_arn" {
  description = "The invoke ARN of the lambda function"
  value       = aws_lambda_function.this.invoke_arn
}
