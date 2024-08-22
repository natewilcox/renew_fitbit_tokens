variable "aws_vpc_id" {
    description = "AWS VPC ID"
    type        = string
    default     = "vpc-dc70bab7"
}

variable "aws_subnet_id" {
    description = "AWS Subnet ID"
    type        = string
    default     = "subnet-eda25f86"
}

variable "aws_security_group_id" {
    description = "Security Group ID"
    type        = string
    default     = "sg-0afe1e73"
}

variable "client_id" {
    description = "Client ID"
    type        = string
    sensitive   = true
}

variable "client_secret" {
    description = "Client Secret"
    type        = string
    sensitive   = true
}