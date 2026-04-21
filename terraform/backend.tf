terraform {
  backend "s3" {
    bucket       = "terraform-aws-tfstate5361" # Replace with your bucket name
    key          = "OtpProject-tfstate/terraform.tfstate" # Replace with your state file path
    region       = "us-east-1"                 # Replace with your AWS region
    use_lockfile = true
  }
}