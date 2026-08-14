mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names    = ["us-east-1a", "us-east-1b", "us-east-1c"]
      zone_ids = ["use1-az1", "use1-az2", "use1-az3"]
    }
  }
}

# Issue #25 regression: static firewall keys with a real unknown policy_arn
# must plan, and entries may differ in optional attributes. This test must fail
# if module.network_firewall wraps var.aws_network_firewall in try().
run "static_firewall_keys_accept_unknown_and_heterogeneous_values" {
  command = plan

  module {
    source = "./tests/fixtures/computed-firewall-policy"
  }
}
