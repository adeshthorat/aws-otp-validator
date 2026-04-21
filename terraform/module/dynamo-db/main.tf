resource "aws_dynamodb_table" "otp_table" {
  name           = var.table_name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = var.hash_key

  # Define the hash key attribute
  attribute {
    name = var.hash_key
    type = var.hash_key_type
  }

  # Dynamically define any other attributes passed by the user
  dynamic "attribute" {
    for_each = var.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  ttl {
    attribute_name = var.ttl_attribute_name
    enabled        = true
  }

  tags = {
    Environment = "Production"
    Project     = "AWS-OTP-Validator"
  }
}
