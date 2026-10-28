# main.tf — all of SkyTicket, described as code (Lesson 7b)

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

# Talk to floci, never to real AWS: fake keys + the floci address for every service we use
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    dynamodb     = "http://localhost.floci.io:4566"
    s3           = "http://localhost.floci.io:4566"
    lambda       = "http://localhost.floci.io:4566"
    apigatewayv2 = "http://localhost.floci.io:4566"
  }
}

# 1. Database: the flights table (Lesson 4)
resource "aws_dynamodb_table" "flights" {
  name         = "skyticket-flights"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "route"
  range_key    = "departure"

  attribute {
    name = "route"
    type = "S"
  }

  attribute {
    name = "departure"
    type = "S"
  }

  tags = {
    project = "skyticket"
  }
}

# 2. Website: the bucket and its website settings (Lesson 1)
resource "aws_s3_bucket" "web" {
  bucket        = "skyticket-web"
  force_destroy = true # allow destroy even when it holds website files
}

resource "aws_s3_bucket_website_configuration" "web" {
  bucket = aws_s3_bucket.web.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# 3. Search function: zip the code, then create the Lambda (Lessons 5a/5b)
data "archive_file" "search" {
  type        = "zip"
  source_file = "${path.module}/../api/search.py"
  output_path = "${path.module}/../api/search.zip"
}

resource "aws_lambda_function" "search" {
  function_name    = "skyticket-search"
  runtime          = "python3.12"
  handler          = "search.handler"
  filename         = data.archive_file.search.output_path
  source_code_hash = data.archive_file.search.output_base64sha256
  role             = "arn:aws:iam::000000000000:role/lambda-role"
}

# 4. API: the front door, pointing at the function (Lesson 6a)
resource "aws_apigatewayv2_api" "search" {
  name          = "skyticket-api"
  protocol_type = "HTTP"
  target        = aws_lambda_function.search.arn
}

# 5. The website's config.js, written with the API's address (Lesson 6b)
resource "local_file" "config" {
  filename = "${path.module}/../frontend/config.js"
  content  = "const API_URL = \"http://${aws_apigatewayv2_api.search.id}.execute-api.localhost.floci.io:4566\";\n"
}

output "website_url" {
  value = "http://${aws_s3_bucket.web.id}.s3-website.localhost.floci.io:4566/"
}

output "api_url" {
  value = "http://${aws_apigatewayv2_api.search.id}.execute-api.localhost.floci.io:4566"
}