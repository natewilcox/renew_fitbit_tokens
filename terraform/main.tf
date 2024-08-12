
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
          "logs:PutLogEvents", "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:logs:*:*:*",
          "${aws_s3_bucket.renew_fitbit_tokens.arn}",
          "${aws_s3_bucket.renew_fitbit_tokens.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "renew_fitbit_tokens" {
  role       = aws_iam_role.renew_fitbit_tokens.name
  policy_arn = aws_iam_policy.renew_fitbit_tokens.arn
}

data "archive_file" "renew_fitbit_tokens" {
  type        = "zip"
  source_dir  = "../lambda_function"
  output_path = "../lambda_function/dist.zip"
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
  }
}