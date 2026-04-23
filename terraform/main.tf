terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# IAM Module for lambda execution role and policies
module "iam" {
  source             = "./module/iam"
  role_name          = "${var.project_name}-lambda-exec-role"
  dynamodb_table_arn = module.dynamodb.table_arn
}

# DynamoDB Module
module "dynamodb" {
  source = "./module/dynamo-db"

  table_name = var.dynamodb_table_name
  hash_key   = "email"
  attributes = var.dynamodb_attributes
}

# Lambda modules
module "lambda_request_otp" {
  source = "./module/lambda"

  function_name          = "RequestOtpFunction"
  zip_path               = "../lambda/zip/requestotp.zip"
  handler                = "requestOtp.lambda_handler"
  role_arn               = module.iam.role_arn
  api_gateway_source_arn = module.api_gateway.execution_arn

  environment_variables = {
    OTP_TTL_SECONDS = var.otp_ttl_seconds
    OTP_TABLE_NAME  = module.dynamodb.table_name
    OTP_HASH_KEY    = "86a26e57248d8075ed9eb1a867b415149a7dd91e5f675901cb7781825c7e954a"
  }
}
module "lambda_verify_otp" {
  source = "./module/lambda"

  function_name          = "VerifyOtpFunction"
  zip_path               = "../lambda/zip/verifyotp.zip"
  handler                = "verifyOtp.lambda_handler"
  role_arn               = module.iam.role_arn
  api_gateway_source_arn = module.api_gateway.execution_arn

  environment_variables = {
    OTP_TTL_SECONDS = var.otp_ttl_seconds
    OTP_TABLE_NAME  = module.dynamodb.table_name
    OTP_HASH_KEY    = "86a26e57248d8075ed9eb1a867b415149a7dd91e5f675901cb7781825c7e954a"

  }
}

# API Gateway Module with regional configuration
module "api_gateway" {
  source      = "./module/api-gateway"
  name        = "${var.project_name}-api"
  description = "API Gateway for OTP validation"
  stage_name  = "dev"
  region      = var.aws_region
  base_path   = "otp"
  endpoints = {
    request = {
      http_method       = "POST"
      lambda_invoke_arn = module.lambda_request_otp.invoke_arn
    }
    verify = {
      http_method       = "POST"
      lambda_invoke_arn = module.lambda_verify_otp.invoke_arn
    }
  }
}
