###############################################################################
# IAM Module
#
# Creates least-privilege IAM roles for:
#   - EC2 Instance Profile (SSM + CloudWatch)
#   - Lambda Execution (logs + VPC)
###############################################################################

###############################################################################
# Local: common assume-role policy fragments
###############################################################################
locals {
  ec2_principal        = { Service = "ec2.amazonaws.com" }
  lambda_principal     = { Service = "lambda.amazonaws.com" }
}



resource "aws_iam_role" "lambda_exec_role" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = local.lambda_principal.Service
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


#inline policy for lambda to access dynamodb table (PutItem, GetItem, DeleteItem)
resource "aws_iam_policy" "dynamodb_access" {
  name        = "${var.role_name}-DynamoDBAccess"
  description = "Provides read and write access to the OTP DynamoDB table"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:DeleteItem"
        ]
        Resource = var.dynamodb_table_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_access" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.dynamodb_access.arn
}

###############################################################################
# EC2 Instance Role + Instance Profile
# Grants EC2 access to Systems Manager & CloudWatch Agent — no SSH keys required.
###############################################################################
resource "aws_iam_role" "ec2" {
  count = var.create_ec2_role ? 1 : 0

  name        = "${var.prefix}-ec2-role"
  description = "EC2 Instance Role SSM Session Manager and CloudWatch agent access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = local.ec2_principal
    }]
  })
}
