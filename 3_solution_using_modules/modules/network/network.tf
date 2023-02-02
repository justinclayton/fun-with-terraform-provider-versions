# As the author of this module, we know the default aws
# provider version for the environment is locked to v3, 
# at least from the envionment where this module will be
# called. Though this doesn't work for our gateway resource
# with its fancy new parameters, we can still utilize the
# newer version that the platform team has made available
# to us through this alternate provider configuration.
# Once v4 is the default, we'll be able to safely go back
# to doing it like everyone else does (how boring).
terraform {
  required_providers {
    aws-new = {
      source = "app.terraform.io/example-org-b68d8e/aws"
      version = "= 4.8.0"
    }
  }
}

# don't forget to also specify the provider here,
# or it will try to use the default one that was 
# implicitly passed down from the calling module
resource "aws_ec2_transit_gateway" "gateway" {
  provider = aws-new
  description = "this is my gateway. there are many like it, but this one is mine"
  transit_gateway_cidr_blocks = ["10.10.10.0/24"] 
}