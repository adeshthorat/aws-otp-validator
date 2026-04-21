# This file contains the variable definitions for the Terraform configuration.

#iam variables
aws_region = "us-east-1"

#lambda variables
otp_ttl_seconds = 300

#dynamodb variables
dynamodb_table_name = "otp-table"
dynamodb_attributes = [
  {
    name = "email"
    type = "S"
  }
]

#api gateway variables
project_name = "otp-validator"
