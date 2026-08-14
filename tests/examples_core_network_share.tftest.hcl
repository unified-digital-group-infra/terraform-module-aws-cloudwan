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

run "validate" {
  command = plan

  module {
    source = "./examples/core_network_share"
  }

  variables {
    aws_account_share = "123456789012"
  }
}
