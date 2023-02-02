## This time we'll show how this concept applies to modules.
## We're also only going to change the name of the hosted
## provider version. This means that existing modules can
## continue to use the `hashicorp/aws` provider, but also
## allows modules that need the newer version to opt-in to
## it by requiring the bespoke `aws-new` provider explicitly.

terraform {
  required_providers {
    # original hashicorp/aws provider, locked to v3
    aws = {
      source = "hashicorp/aws"
      version = "= 3.76.1"
    }

    # a v4 version of the provider, hosted by us as before.
    # in this case, the provider binary is located at:
    # $HOME/.terraform.d/plugins/example.com/examplecorp/aws/4.8.0/darwin_arm64/terraform-provider-aws_v4.8.0_x5
    aws-new = {
      source = "app.terraform.io/example-org-b68d8e/aws"
      version = "= 4.8.0"
    }
  }
}

# v3
provider "aws" {
  region = "us-west-2"
}

# v4, locally mirrored
provider "aws-new" {
  region = "us-west-2"
}

# While it's generally permitted to explicitly pass a provider
# (or provider alias) when calling a module, in this specific
# case, we can't simply pass the `aws-new` provider to the module
# that needs it; instead we have to let the resources inside the
# child module decide which provider to use. This is because the
# default `aws` provider is also being implicitly passed into
# the child module, which will cause a conflict if the provider
# is not explicitly specified at the resource level.

module "dev" {
  source = "./modules/dev"
}

module "network" {
  source = "./modules/network"
}