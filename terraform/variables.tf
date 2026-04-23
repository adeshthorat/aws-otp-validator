variable "aws_region" {
  description = "AWS Region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "otp_hash_key" {
  description = "Hash key name for OTP in DynamoDB"
  type        = string
  default     = "86a26e57248d8075ed9eb1a867b415149a7dd91e5f675901cb7781b1c9"

}

variable "create-ec2-role" {
  description = "Whether to create an EC2 Instance Role and Instance Profile for Systems Manager access (true/false)"
  type        = bool
  default     = false
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "aws-otp-validator"
}

variable "otp_ttl_seconds" {
  description = "Time to live for OTP in seconds"
  type        = string
  default     = "300"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  type        = string
  default     = "otp-table"
}

variable "dynamodb_attributes" {
  description = "Array of additional attributes (each as an object with name and type) to define in the table. Type should be S, N, or B."
  type = list(object({
    name = string
    type = string
  }))
  default = []
}
