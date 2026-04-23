variable "role_name" {
  description = "The name of the IAM role for the Lambda functions"
  type        = string
  default     = "LambdaExecutionRole"
}

variable "dynamodb_table_arn" {
  description = "The ARN of the DynamoDB table the Lambda needs access to"
  type        = string
}

variable "create_ec2_role" {
  description = "Whether to create an EC2 Instance Role and Instance Profile."
  type        = bool
  default     = false
}

variable "ec2_extra_policy_arn" {
  description = "ARN of an additional IAM policy to attach to the EC2 Role (e.g., for S3 or DynamoDB access)."
  type        = string
  default     = ""
}

variable "prefix" {
  description = "Prefix for naming AWS resources (e.g., roles, policies)."
  type        = string
  default     = "api"
  
}