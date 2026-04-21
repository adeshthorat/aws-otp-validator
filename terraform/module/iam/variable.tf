variable "role_name" {
  description = "The name of the IAM role for the Lambda functions"
  type        = string
  default     = "LambdaExecutionRole"
}

variable "dynamodb_table_arn" {
  description = "The ARN of the DynamoDB table the Lambda needs access to"
  type        = string
}
