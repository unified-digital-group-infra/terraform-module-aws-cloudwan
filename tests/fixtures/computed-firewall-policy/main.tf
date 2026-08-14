terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
  }
}

# Regression fixture for issue #25: terraform_data.computed.id is unknown
# during planning. Static firewall keys must remain usable even though one
# policy_arn is unknown, and optional attributes may differ per entry.
resource "terraform_data" "computed" {
  input = "computed-policy"
}

module "cloudwan" {
  source = "../../.."

  core_network_arn        = "arn:aws:networkmanager::123456789012:core-network/core-network-0123456789abcdef0"
  ipv4_network_definition = "10.0.0.0/8"

  central_vpcs = {
    inspection-minimal = {
      type       = "inspection"
      name       = "inspection-minimal-vpc"
      cidr_block = "10.10.0.0/24"
      az_count   = 2

      subnets = {
        endpoints    = { netmask = 28 }
        core_network = { netmask = 28 }
      }
    }

    inspection-protected = {
      type       = "inspection"
      name       = "inspection-protected-vpc"
      cidr_block = "10.20.0.0/24"
      az_count   = 2

      subnets = {
        endpoints    = { netmask = 28 }
        core_network = { netmask = 28 }
      }
    }
  }

  aws_network_firewall = {
    inspection-minimal = {
      name        = "inspection-minimal-firewall"
      description = "Firewall whose policy ID is unknown during planning"
      policy_arn  = terraform_data.computed.id
    }

    inspection-protected = {
      name                     = "inspection-protected-firewall"
      description              = "Firewall with per-entry optional attributes"
      policy_arn               = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/protected"
      delete_protection        = true
      policy_change_protection = true
      subnet_change_protection = true
      tags                     = { Protection = "enabled" }
    }
  }
}
