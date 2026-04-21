output "role_arn" {
  description = "The ARN of the created IAM role"
  value       = aws_iam_role.lambda_exec_role.arn
}
