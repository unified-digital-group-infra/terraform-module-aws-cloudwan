mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names    = ["us-east-1a"]
      zone_ids = ["use1-az1"]
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_subnet" {
    defaults = {
      cidr_block = "10.0.0.0/28"
    }
  }
}

override_module {
  target = module.tags
  outputs = {
    tags_aws = {}
  }
}

override_module {
  target = module.global_network_tags
  outputs = {
    tags_aws = {}
  }
}

override_module {
  target = module.core_network_tags
  outputs = {
    tags_aws = {}
  }
}

override_module {
  target = module.central_vpcs
  outputs = {
    vpc_attributes = {
      id = "vpc-0123456789abcdef0"
    }
    private_subnet_attributes_by_az = {}
    public_subnet_attributes_by_az  = {}
    rt_attributes_by_type_by_az = {
      core_network = {}
      public       = {}
    }
    internet_gateway = {
      id = "igw-0123456789abcdef0"
    }
    core_network_attachment = {
      id = "attachment-0123456789abcdef0"
    }
  }
}

override_module {
  target = module.network_firewall
  outputs = {
    aws_network_firewall = {
      id = "arn:aws:network-firewall:us-east-1:123456789012:firewall/test"
    }
  }
}

run "empty_configuration_is_valid" {
  command = plan

  assert {
    condition = (
      output.central_vpcs == {} &&
      output.central_vpc_ids == {} &&
      output.core_network_attachment_ids == {} &&
      output.global_network_id == null &&
      output.core_network_id == null
    )
    error_message = "The empty compatibility configuration must remain a no-op with empty Tier 1 maps."
  }
}

run "shared_services_excludes_reserved_subnets" {
  command = plan

  assert {
    condition = length(regexall(
      "k != \"public\" && k != \"core_network\"",
      file("${path.module}/main.tf")
    )) == 1
    error_message = "Shared-services routes must exclude both public and core_network subnet groups."
  }
}

run "valid_global_network_id" {
  command = plan

  variables {
    global_network_id = "global-network-0123456789abcdef0"
  }

  assert {
    condition     = output.global_network_arn == "arn:aws:networkmanager::123456789012:global-network/global-network-0123456789abcdef0"
    error_message = "A valid referenced Global Network ID must produce the stable ARN handle."
  }
}

run "invalid_global_network_id" {
  command = plan

  variables {
    global_network_id = "global-network-not-hex"
  }

  expect_failures = [var.global_network_id]
}

run "valid_core_network_arn" {
  command = plan

  variables {
    core_network_arn = "arn:aws:networkmanager::123456789012:core-network/core-network-0123456789abcdef0"
  }

  assert {
    condition     = output.core_network_id == "core-network-0123456789abcdef0"
    error_message = "A valid referenced Core Network ARN must produce the stable ID handle."
  }
}

run "invalid_core_network_arn" {
  command = plan

  variables {
    core_network_arn = "garbage/core-network/core-network-01234567"
  }

  expect_failures = [var.core_network_arn]
}

run "valid_created_network_shapes_and_policy" {
  command = plan

  variables {
    global_network = {
      description = "unit-global"
      tags        = { Environment = "test" }
    }
    core_network = {
      description = "unit-core"
      policy_document = jsonencode({
        version                    = "2021.12"
        core-network-configuration = {}
        segments                   = []
      })
      base_policy_regions = ["us-east-1"]
      tags                = { Environment = "test" }
    }
  }
}

run "invalid_global_network_shape" {
  command = plan

  variables {
    global_network = {
      description = 42
    }
  }

  expect_failures = [var.global_network]
}

run "invalid_core_network_shape" {
  command = plan

  variables {
    global_network_id = "global-network-0123456789abcdef0"
    core_network = {
      description = "missing-policy"
    }
  }

  expect_failures = [var.core_network]
}

run "invalid_base_policy_xor" {
  command = plan

  variables {
    global_network_id = "global-network-0123456789abcdef0"
    core_network = {
      description = "invalid-bootstrap"
      policy_document = jsonencode({
        version                    = "2021.12"
        core-network-configuration = {}
        segments                   = []
      })
      base_policy_document = jsonencode({
        version                    = "2021.12"
        core-network-configuration = {}
        segments                   = []
      })
      base_policy_regions = ["us-east-1"]
    }
  }

  expect_failures = [var.core_network]
}

run "invalid_policy_json" {
  command = plan

  variables {
    global_network_id = "global-network-0123456789abcdef0"
    core_network = {
      description     = "invalid-json"
      policy_document = "{not-json}"
    }
  }

  expect_failures = [var.core_network]
}

run "invalid_policy_segments_shape" {
  command = plan

  variables {
    global_network_id = "global-network-0123456789abcdef0"
    core_network = {
      description = "invalid-segments"
      policy_document = jsonencode({
        version                    = "2021.12"
        core-network-configuration = {}
        segments                   = { shared = {} }
      })
    }
  }

  expect_failures = [var.core_network]
}

run "valid_central_vpc_cidr_shape" {
  command = plan

  variables {
    core_network_arn = "arn:aws:networkmanager::123456789012:core-network/core-network-0123456789abcdef0"
    central_vpcs = {
      inspection = {
        type       = "inspection"
        cidr_block = "10.0.0.0/24"
        az_count   = 1
        subnets = {
          endpoints    = { netmask = 28 }
          core_network = { netmask = 28, tags = { domain = "inspection" } }
        }
      }
    }
  }
}

run "valid_central_vpc_ipam_shape" {
  command = plan

  variables {
    core_network_arn = "arn:aws:networkmanager::123456789012:core-network/core-network-0123456789abcdef0"
    central_vpcs = {
      inspection = {
        type                    = "inspection"
        vpc_ipv4_ipam_pool_id   = "ipam-pool-0123456789abcdef0"
        vpc_ipv4_netmask_length = 24
        az_count                = 1
        subnets = {
          endpoints    = { netmask = 28 }
          core_network = { netmask = 28 }
        }
      }
    }
  }
}

run "invalid_central_vpc_required_fields" {
  command = plan

  variables {
    central_vpcs = {
      invalid = {
        cidr_block = "10.0.0.0/24"
      }
    }
  }

  expect_failures = [var.central_vpcs]
}

run "invalid_central_vpc_addressing_xor" {
  command = plan

  variables {
    central_vpcs = {
      invalid = {
        type                    = "inspection"
        cidr_block              = "10.0.0.0/24"
        vpc_ipv4_ipam_pool_id   = "ipam-pool-0123456789abcdef0"
        vpc_ipv4_netmask_length = 24
        az_count                = 1
        subnets                 = { core_network = { netmask = 28 } }
      }
    }
  }

  expect_failures = [var.central_vpcs]
}

run "invalid_central_vpc_subnet_shape" {
  command = plan

  variables {
    central_vpcs = {
      invalid = {
        type       = "inspection"
        cidr_block = "10.0.0.0/24"
        az_count   = 1
        subnets = {
          core_network = {
            cidrs   = ["10.0.0.0/28", "10.0.0.16/28"]
            netmask = 28
          }
        }
      }
    }
  }

  expect_failures = [var.central_vpcs]
}

run "invalid_central_vpc_optional_types" {
  command = plan

  variables {
    central_vpcs = {
      invalid = {
        type                   = "inspection"
        cidr_block             = "10.0.0.0/24"
        az_count               = 1
        vpc_enable_dns_support = "not-a-boolean"
        subnets                = { core_network = { netmask = 28 } }
      }
    }
  }

  expect_failures = [var.central_vpcs]
}

run "valid_ipv4_cidr_definition" {
  command = plan

  variables {
    ipv4_network_definition = "10.0.0.0/8"
  }
}

run "valid_ipv4_prefix_list_definition" {
  command = plan

  variables {
    ipv4_network_definition = "pl-0123456789abcdef0"
  }
}

run "invalid_ipv4_network_definition" {
  command = plan

  variables {
    ipv4_network_definition = "2001:db8::/32"
  }

  expect_failures = [var.ipv4_network_definition]
}

run "valid_network_firewall_shape" {
  command = plan

  variables {
    core_network_arn = "arn:aws:networkmanager::123456789012:core-network/core-network-0123456789abcdef0"
    central_vpcs = {
      inspection = {
        type       = "inspection"
        cidr_block = "10.0.0.0/24"
        az_count   = 1
        subnets = {
          endpoints    = { netmask = 28 }
          core_network = { netmask = 28 }
        }
      }
    }
    aws_network_firewall = {
      inspection = {
        name        = "inspection"
        description = "Contract test"
        policy_arn  = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/test"
        tags        = { Environment = "test" }
      }
    }
  }
}

run "network_firewall_required_fields_are_typed" {
  command = plan

  assert {
    condition = alltrue([
      for declaration in [
        "name                     = string",
        "description              = string",
        "policy_arn               = string"
      ] : strcontains(file("${path.module}/variables.tf"), declaration)
    ])
    error_message = "Network Firewall entries must require string name, description, and policy_arn attributes in the productive type."
  }
}

run "network_firewall_optional_fields_are_typed" {
  command = plan

  assert {
    condition = alltrue([
      for declaration in [
        "delete_protection        = optional(bool)",
        "policy_change_protection = optional(bool)",
        "subnet_change_protection = optional(bool)",
        "tags                     = optional(map(string))"
      ] : strcontains(file("${path.module}/variables.tf"), declaration)
    ])
    error_message = "Network Firewall per-entry protections and tags must remain typed optional attributes."
  }
}

run "global_network_xor_rejects_both_sources" {
  command = plan

  variables {
    global_network_id = "global-network-0123456789abcdef0"
    global_network = {
      description = "ambiguous"
    }
  }

  expect_failures = [output.global_network]
}

run "global_network_xor_requires_source_for_created_core" {
  command = plan

  variables {
    core_network = {
      description = "missing-global"
      policy_document = jsonencode({
        version                    = "2021.12"
        core-network-configuration = {}
        segments                   = []
      })
    }
  }

  expect_failures = [output.global_network]
}

run "core_network_xor_rejects_both_sources" {
  command = plan

  variables {
    global_network_id = "global-network-0123456789abcdef0"
    core_network_arn  = "arn:aws:networkmanager::123456789012:core-network/core-network-0123456789abcdef0"
    core_network = {
      description = "ambiguous"
      policy_document = jsonencode({
        version                    = "2021.12"
        core-network-configuration = {}
        segments                   = []
      })
    }
  }

  expect_failures = [output.core_network]
}

run "core_network_xor_requires_source_for_central_vpcs" {
  command = plan

  variables {
    central_vpcs = {
      inspection = {
        type       = "inspection"
        cidr_block = "10.0.0.0/24"
        az_count   = 1
        subnets = {
          endpoints    = { netmask = 28 }
          core_network = { netmask = 28 }
        }
      }
    }
  }

  expect_failures = [output.core_network]
}

run "valid_shared_services_subnet_contract" {
  command = plan

  variables {
    core_network_arn = "arn:aws:networkmanager::123456789012:core-network/core-network-0123456789abcdef0"
    central_vpcs = {
      shared = {
        type       = "shared_services"
        cidr_block = "10.0.0.0/24"
        az_count   = 1
        subnets = {
          services     = { netmask = 28 }
          core_network = { netmask = 28 }
        }
      }
    }
  }
}

run "valid_shared_services_core_network_only" {
  command = plan

  variables {
    core_network_arn = "arn:aws:networkmanager::123456789012:core-network/core-network-0123456789abcdef0"
    central_vpcs = {
      shared = {
        type       = "shared_services"
        cidr_block = "10.0.0.0/24"
        az_count   = 1
        subnets = {
          core_network = { netmask = 28 }
        }
      }
    }
  }
}

run "firewall_key_must_match_central_vpc" {
  command = plan

  variables {
    aws_network_firewall = {
      missing = {
        name        = "missing"
        description = "Contract test"
        policy_arn  = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/test"
      }
    }
  }

  expect_failures = [output.aws_network_firewall]
}

run "firewall_requires_compatible_central_vpc_type" {
  command = plan

  variables {
    core_network_arn = "arn:aws:networkmanager::123456789012:core-network/core-network-0123456789abcdef0"
    central_vpcs = {
      shared = {
        type       = "shared_services"
        cidr_block = "10.0.0.0/24"
        az_count   = 1
        subnets = {
          services     = { netmask = 28 }
          core_network = { netmask = 28 }
        }
      }
    }

    aws_network_firewall = {
      shared = {
        name        = "shared"
        description = "Contract test"
        policy_arn  = "arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/test"
      }
    }
  }

  expect_failures = [output.aws_network_firewall]
}

run "subnet_helper_accepts_matching_cardinality" {
  command = plan

  module {
    source = "./modules/subnet_cidrs"
  }

  variables {
    subnet_ids = {
      "us-east-1a" = "subnet-0123456789abcdef0"
    }
    number_azs = 1
  }
}

run "subnet_helper_rejects_mismatched_cardinality" {
  command = plan

  module {
    source = "./modules/subnet_cidrs"
  }

  variables {
    subnet_ids = {
      "us-east-1a" = "subnet-0123456789abcdef0"
    }
    number_azs = 2
  }

  expect_failures = [data.aws_subnet.subnet]
}
