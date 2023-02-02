## how to maintain two parallel versions of
## the same provider within the same workspace

## copy one version of the provider and host it yourself in one of two ways. either  
##
## 1) using a private registry:
## (https://developer.hashicorp.com/terraform/cloud-docs/registry/publish-providers), or
##
## 2) in a local directory following this structure:
## $HOME/.terraform.d/plugins/<HOSTNAME>/<ORGNAME>/<PROVIDERNAME>/<VERSION>/<ARCH>/terraform-provider-<PROVIDERNAME>
## (use $HOME/.terraformrc file to tell terraform where to find the provider by setting `plugin_cache_dir`.)
##
## then, in the `required_providers` block, give the providers different names
## and declare your version contraints. this will allow both versions of the provider
## to be downloaded on `terraform init`. at this point, either version can be declared
## and used by resources and modules within the same terraform workspace.

terraform {
  required_providers {
    # in this case, the provider binary is located at:
    # $HOME/.terraform.d/plugins/example.com/examplecorp/aws/3.76.1/darwin_arm64/terraform-provider-aws
    aws-three = {
      source = "example.com/examplecorp/aws"
      version = "= 3.76.1"
    }

    aws-four = {
      source = "hashicorp/aws"
      version = "= 4.8.0"
    }
  }
}

# note that these are not provider aliases,
# but distinct providers according to terraform
provider "aws-three" {
  region = "us-west-2"
}

provider "aws-four" {
  region = "us-west-2"
}

# in aws 4.0-4.8, acl was not a valid parameter
# so this will fail unless you use 3.x or 4.9+
resource "aws_s3_bucket" "bucket" {
  provider = aws-three
  bucket_prefix = "my-s3-bucket-"
  acl = "private"
}

# transit_gateway_cidr_blocks was added in v4
# so this will fail if you try to use it with v3
resource "aws_ec2_transit_gateway" "gateway" {
  provider = aws-four
  description = "just look at this gateway, isn't it great"
  transit_gateway_cidr_blocks = ["10.10.10.0/24"] 
}