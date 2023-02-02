## In this example, this code can never be successfully
## applied, because the resources require different versions 
## of the aws provider -- versions which are mutually exclusive.
## 
## Try swapping the provider versions. After running `terraform init`
## and `terraform plan`, one of the resources will always produce an error.
## 
## (And before you say it, yes, I know that it will work with v4.9 or above,
## don't @ me. This example is meant to prepare us for the deprecations
## coming in v5, which will definitely be happening whether we want it or not.)

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "= 3.76.1"
      # version = "= 4.8.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

# in aws 4.0-4.8, acl was not a valid parameter
# so this will fail unless you use 3.x or 4.9+
resource "aws_s3_bucket" "bucket" {
  bucket_prefix = "my-s3-bucket-"
  acl = "private"
}

# transit_gateway_cidr_blocks was added in v4
# so this will fail if you try to use it with v3
resource "aws_ec2_transit_gateway" "gateway" {
  description = "my shiny new gateway"
  transit_gateway_cidr_blocks = ["10.10.10.0/24"] 
}