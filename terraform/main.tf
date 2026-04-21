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

# IAM Module
module "iam" {
  source = "./module/iam"

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

# Lambda Modules
module "lambda_request_otp" {
  source = "./module/lambda"

  function_name          = "RequestOtpFunction"
  zip_path               = "../lambda/zip/request-otp.zip"
  handler                = "request-otp.lambda_handler"
  role_arn               = module.iam.role_arn
  api_gateway_source_arn = module.api_gateway.execution_arn

  environment_variables = {
    OTP_TTL_SECONDS = var.otp_ttl_seconds
    OTP_TABLE_NAME  = module.dynamodb.table_name
  }
}
module "lambda_verify_otp" {
  source = "./module/lambda"

  function_name          = "VerifyOtpFunction"
  zip_path               = "../lambda/zip/verify-otp.zip"
  handler                = "verify-otp.lambda_handler"
  role_arn               = module.iam.role_arn
  api_gateway_source_arn = module.api_gateway.execution_arn

  environment_variables = {
    OTP_TTL_SECONDS = var.otp_ttl_seconds
    OTP_TABLE_NAME  = module.dynamodb.table_name
    OTP_HASH_KEY    = var.otp_hash_key
  }
}

# API Gateway Module
module "api_gateway" {
  source = "./module/api-gateway"
  name        = "${var.project_name}-api"
  description = "API Gateway for OTP validation"
  stage_name  = "prod"
  endpoints = {
    request = {
      path              = "requestOtp"
      http_method       = "POST"
      lambda_invoke_arn = module.lambda_request_otp.invoke_arn
    }
    verify = {
      path              = "verifyOtp"
      http_method       = "POST"
      lambda_invoke_arn = module.lambda_verify_otp.invoke_arn
    }
  }
  request_lambda_invoke_arn = module.lambda_request_otp.invoke_arn
  verify_lambda_invoke_arn  = module.lambda_verify_otp.invoke_arn
}
