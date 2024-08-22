data "aws_vpc" "default" {
  id = var.aws_vpc_id
}

data "aws_subnet" "default" {
  id = var.aws_subnet_id
}

data "aws_security_group" "default" {
  id = var.aws_security_group_id
}

data "archive_file" "renew_fitbit_tokens" {
  type        = "zip"
  source_dir  = "../lambda_function"
  output_path = "../dist.zip"
}