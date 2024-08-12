terraform {
  backend "s3" {
    bucket = "terraform-state-natewilcox-io"
    key    = "workloads/terraform_lambda/terraform.tfstate"
    region = "us-east-2"
  }
}