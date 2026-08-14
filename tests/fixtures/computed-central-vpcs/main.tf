terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
  }
}

resource "terraform_data" "computed" {
  input = {
    name       = "computed-inspection-vpc"
    cidr_block = "10.30.0.0/24"
  }
}

module "cloudwan" {
  source = "../../.."

  core_network_arn = "arn:aws:networkmanager::123456789012:core-network/core-network-0123456789abcdef0"

  central_vpcs = {
    computed = {
      type       = "inspection"
      name       = terraform_data.computed.output.name
      cidr_block = terraform_data.computed.output.cidr_block
      az_count   = 2

      subnets = {
        endpoints    = { netmask = 28 }
        core_network = { netmask = 28 }
      }
    }
  }
}
