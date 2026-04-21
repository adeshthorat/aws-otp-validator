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

variable "base_path" {
  description = "Base path for the API endpoints"
  type        = string
  default     = ""
}

variable "endpoints" {
  description = "Map of API endpoints with their configurations"
  type = map(object({
    http_method       = string
    lambda_invoke_arn = string
  }) 
  )
}
