mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names    = ["us-east-1a", "us-east-1b", "us-east-1c"]
      zone_ids = ["use1-az1", "use1-az2", "use1-az3"]
    }
  }

  mock_data "aws_networkmanager_core_network_policy_document" {
    defaults = {
      json = "{\"version\":\"2021.12\",\"core-network-configuration\":{},\"segments\":[]}"
    }
  }
}

override_module {
  target = module.cwan_central_vpcs.module.public_subnet_cidrs
  outputs = {
    subnet_cidrs = ["10.10.5.0/28", "10.10.5.16/28"]
  }
}

run "core_network" {
  command = plan

  plan_options {
    target = [module.cloud_wan]
  }

  module {
    source = "./examples/central_vpcs"
  }
}

run "validate" {
  command = plan

  module {
    source = "./examples/central_vpcs"
  }
}

