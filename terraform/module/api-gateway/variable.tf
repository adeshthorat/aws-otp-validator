variable "name" {
  description = "Name for api gateway"
  type        = string
}

variable "region" {
   description = "AWS Region to deploy to"
   type        = string
   default = "us-east-1"
}

variable "description" {
  description = "Description for api gateway"
  type        = string
  default     = "AWS OTP Validator API Gateway"
}

variable "stage_name" {
  description = "Stage name for api gateway deployment"
  type        = string
  default     = "prod"
}

variable "request_lambda_invoke_arn" {
  description = "Invoke ARN of the Request OTP Lambda function"
  type        = string
}

variable "verify_lambda_invoke_arn" {
  description = "Invoke ARN of the Verify OTP Lambda function"
  type        = string
}

variable "endpoints" {
  description = "Map of API endpoints with their configurations"
  type = map(object({
    path              = string
    http_method       = string
    lambda_invoke_arn = string
  }))
  
}