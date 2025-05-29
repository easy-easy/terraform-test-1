terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "ap-northeast-1"
  profile = "c1"
}

// アカウントID取得
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "sample_bucket" {
  bucket = "sample-terraform-s3-lambda-bucket-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "random_id" "bucket_id" {
  byte_length = 4
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "sample_lambda" {
  function_name = "sample_lambda_function"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.10"
  filename      = "lambda_function_payload.zip"
  source_code_hash = filebase64sha256("lambda_function_payload.zip")
  environment {
    variables = {
      BUCKET = aws_s3_bucket.sample_bucket.bucket
    }
  }
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.sample_bucket.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.sample_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.allow_s3]
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sample_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.sample_bucket.arn
}
