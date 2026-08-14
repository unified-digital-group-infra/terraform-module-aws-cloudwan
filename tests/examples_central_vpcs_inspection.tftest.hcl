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

mock_provider "http" {
  mock_data "http" {
    defaults = {
      response_body = jsonencode({ ip = "192.0.2.1" })
    }
  }
}

override_module {
  target = module.cloudwan_central_vpcs.module.public_subnet_cidrs
  outputs = {
    subnet_cidrs = ["10.10.2.0/28", "10.10.2.16/28"]
  }
}

run "core_network" {
  command = plan

  plan_options {
    target = [module.cloud_wan]
  }

  module {
    source = "./examples/central_vpcs_inspection"
  }
}

run "validate" {
  command = plan

  module {
    source = "./examples/central_vpcs_inspection"
  }
}