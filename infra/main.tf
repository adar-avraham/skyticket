# main.tf — SkyTicket infrastructure, described as code (Lesson 7a)

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Talk to floci, never to real AWS: fake keys + the floci address
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    dynamodb = "http://localhost.floci.io:4566"
  }
}

# The flights table from Lesson 4 — same settings, written as code
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