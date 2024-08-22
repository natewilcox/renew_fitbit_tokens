
resource "aws_iam_role" "renew_fitbit_tokens" {
  name = "renew_fitbit_tokens_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
        Sid    = ""
      }
    ]
  })
}

resource "aws_iam_policy" "renew_fitbit_tokens" {
  name        = "renew_fitbit_tokens_policy"
  path        = "/"
  description = "Allow lambda to write logs to CloudWatch and access s3 cache"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents", 
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:logs:*:*:*",
          "${aws_s3_bucket.renew_fitbit_tokens.arn}",
          "${aws_s3_bucket.renew_fitbit_tokens.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = aws_secretsmanager_secret.renew_fitbit_tokens.arn
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt"
        ],
        Resource = aws_kms_key.example.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "renew_fitbit_tokens" {
  role       = aws_iam_role.renew_fitbit_tokens.name
  policy_arn = aws_iam_policy.renew_fitbit_tokens.arn
}

resource "aws_iam_role_policy_attachment" "iam_role_policy_attachment_lambda_vpc_access_execution" {
  role       = aws_iam_role.renew_fitbit_tokens.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_lambda_function" "renew_fitbit_tokens" {
  function_name    = "RenewFitbitTokens"
  role             = aws_iam_role.renew_fitbit_tokens.arn
  handler          = "function.lambdaHandler"
  runtime          = "nodejs20.x"
  timeout          = 15
  filename         = data.archive_file.renew_fitbit_tokens.output_path
  source_code_hash = data.archive_file.renew_fitbit_tokens.output_base64sha256
  depends_on       = [aws_iam_role_policy_attachment.renew_fitbit_tokens]

  # This would cost too much money
  # vpc_config {
  #   subnet_ids         = [data.aws_subnet.default.id]
  #   security_group_ids = [data.aws_security_group.default.id]
  # }
}

resource "aws_cloudwatch_event_rule" "renew_fitbit_tokens" {
  name                = "renew_fitbit_tokens_daily"
  schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_target" "renew_fitbit_tokens" {
  rule = aws_cloudwatch_event_rule.renew_fitbit_tokens.name
  arn  = aws_lambda_function.renew_fitbit_tokens.arn
}

resource "aws_lambda_permission" "renew_fitbit_tokens" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.renew_fitbit_tokens.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.renew_fitbit_tokens.arn
}

resource "aws_s3_bucket" "renew_fitbit_tokens" {
  bucket = "fitbit-tokens"
}

resource "aws_s3_object" "renew_fitbit_tokens" {
  bucket = aws_s3_bucket.renew_fitbit_tokens.bucket
  key    = "tokens.json"
  source = "../tokens.json"

  lifecycle {
    prevent_destroy = true

    ignore_changes = [
      tags_all
    ]
  }
}

# resource "aws_vpc_endpoint" "s3" {
#   vpc_id       = data.aws_vpc.default.id
#   service_name = "com.amazonaws.us-east-2.s3"
#   route_table_ids = [aws_route_table.s3_endpoint_route_table.id]
# }

# resource "aws_route_table" "s3_endpoint_route_table" {
#   vpc_id = data.aws_vpc.default.id
# }

# resource "aws_route" "s3_endpoint_route" {
#   route_table_id         = aws_route_table.s3_endpoint_route_table.id
#   destination_cidr_block = "0.0.0.0/0"
#   vpc_endpoint_id        = aws_vpc_endpoint.s3.id

#   depends_on = [aws_vpc_endpoint.s3]
# }

# resource "aws_route_table_association" "s3_endpoint_route_table_association" {
#   subnet_id      = data.aws_subnet.default.id
#   route_table_id = aws_route_table.s3_endpoint_route_table.id
# }

# resource "aws_subnet" "private_subnet" {
#   vpc_id            = data.aws_vpc.default.id
#   cidr_block        = "172.31.48.0/20"
#   availability_zone = "us-east-2a"
#   map_public_ip_on_launch = false

#   tags = {
#     Name = "Private Subnet"
#   }
# }

# resource "aws_route_table" "private_route_table" {
#   vpc_id = data.aws_vpc.default.id

#   tags = {
#     Name = "Private Route Table"
#   }
# }

# resource "aws_route_table_association" "private_route_table_association" {
#   subnet_id      = aws_subnet.private_subnet.id
#   route_table_id = aws_route_table.private_route_table.id
# }

# resource "aws_nat_gateway" "nat_gateway" {
#   allocation_id = aws_eip.nat_eip.id
#   subnet_id    = aws_subnet.private_subnet.id

#   tags = {
#     Name = "NAT Gateway"
#   }
# }

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "example" {
  description             = "An example symmetric encryption KMS key"
  enable_key_rotation     = true
  deletion_window_in_days = 20
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "key-default-1"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::607827195774:user/natewilcox"
        },
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow use of the key"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::607827195774:role/renew_fitbit_tokens_role"
        },
        Action = [
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_secretsmanager_secret" "renew_fitbit_tokens" {
  name = "api"
  kms_key_id = aws_kms_key.example.id
}

resource "aws_secretsmanager_secret_version" "renew_fitbit_tokens" {
  secret_id     = aws_secretsmanager_secret.renew_fitbit_tokens.id
  secret_string = jsonencode({
    client_id     = var.client_id,
    client_secret = var.client_secret
  })
}