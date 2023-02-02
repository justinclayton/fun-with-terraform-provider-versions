## setting `required_providers` in the child module is
## recommended, but not strictly required. If omitted,
## this child module would inherit the default `aws`
## provider, which was pinned to v3 in the root module
## For the sake clarity, however, Hashicorp recommends
## explicitly setting the provider in each module, 
## especially when speciic requirements must be met.

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 3"
    }
  }
}

# in aws 4.0-4.8, `acl` was not a valid parameter
# so this will fail unless you use 3.x or 4.9+
resource "aws_s3_bucket" "bucket" {
  bucket_prefix = "my-s3-bucket-"
  acl = "private"
}