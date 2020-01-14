provider "aws" {
  profile = var.profile
  region  = var.region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

#
# S3
#
resource "aws_s3_bucket" "gitlfs" {
  bucket        = var.gitlfs_s3_bucket
  acl           = "private"
  force_destroy = true
}

#
# Lambda
#
resource "aws_iam_role" "gitlfs_lambda_role" {
  name = "${var.name}-gitlfs"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "s3_fullaccess_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.gitlfs_lambda_role.id
}

resource "aws_iam_role_policy_attachment" "lambda_execution_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.gitlfs_lambda_role.id
}

resource "aws_lambda_function" "gitlfs" {
  filename      = "lambda/Estranged.Lfs.Hosting.Lambda.zip"
  function_name = "${var.name}-gitlfs"
  description   = "Generates S3 signed URLs for Git LFS"
  role          = aws_iam_role.gitlfs_lambda_role.arn
  handler       = "Estranged.Lfs.Hosting.Lambda::Estranged.Lfs.Hosting.Lambda.LambdaEntryPoint::FunctionHandlerAsync"
  runtime       = "dotnetcore2.1"
  timeout       = 30

  environment {
    variables = {
      LFS_BUCKET   = aws_s3_bucket.gitlfs.bucket
      LFS_USERNAME = var.gitlfs_username
      LFS_PASSWORD = var.gitlfs_password
    }
  }
}

resource "aws_lambda_permission" "gitlfs_lambda_permission" {
  statement_id  = "AllowGitLFSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.gitlfs.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.gitlfs.id}/*"
}

#
# API Gateway
#
resource "aws_api_gateway_rest_api" "gitlfs" {
  name        = "Git LFS REST API"
  description = "Describes a proxy to a Lambda function to sign S3 requests."

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "execute-api:Invoke",
      "Resource": "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*",
      "Condition": {
        "IpAddress": {
          "aws:SourceIp": ${jsonencode(var.gitlfs_allow_ips)}
        }
      }
    }
  ]
}
EOF

  body = <<EOF
{
    "swagger": "2.0",
    "info": {
        "description": "Describes a proxy to a Lambda function to sign S3 requests.",
        "title": "Git LFS REST API"
    },
    "version": "1.0.0",
    "paths": {
        "/{proxy+}": {
            "x-amazon-apigateway-any-method": {
                "produces": [
                    "application/json"
                ],
                "parameters": [
                    {
                        "name": "proxy",
                        "in": "path",
                        "required": true,
                        "type": "string"
                    }
                ],
                "responses": {},
                "x-amazon-apigateway-integration": {
                    "responses": {
                        "default": {
                            "statusCode": 200
                        }
                    },
                    "uri": "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${aws_lambda_function.gitlfs.function_name}/invocations",
                    "passthroughBehavior": "when_no_match",
                    "httpMethod": "POST",
                    "contentHandling": "CONVERT_TO_TEXT",
                    "type": "aws_proxy"
                }
            }
        }
    }
}
EOF
}

resource "aws_api_gateway_deployment" "gitlfs" {
  rest_api_id = aws_api_gateway_rest_api.gitlfs.id
  stage_name  = "lfs"
}

#
# Output
#
output "gitlfs_url" {
  value = "https://${var.gitlfs_username}:${var.gitlfs_password}@${aws_api_gateway_rest_api.gitlfs.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_deployment.gitlfs.stage_name}"
}
