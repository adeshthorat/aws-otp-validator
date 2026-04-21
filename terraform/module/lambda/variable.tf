variable "function_name" {
  description = "The name of the Lambda function"
  type        = string
}

variable "zip_path" {
  description = "Path to the local zip file containing lambda code"
  type        = string
}

variable "handler" {
  description = "The function handler"
  type        = string
  default     = "index.lambda_handler"
}

variable "runtime" {
  description = "The lambda runtime"
  type        = string
  default     = "python3.9"
}

variable "role_arn" {
  description = "The ARN of the IAM role for the lambda"
  type        = string
}

variable "environment_variables" {
  description = "Environment variables for the lambda"
  type        = map(string)
  default     = {}
}

variable "api_gateway_source_arn" {
  description = "Execution ARN of the API Gateway to allow invocation"
  type        = string
}
