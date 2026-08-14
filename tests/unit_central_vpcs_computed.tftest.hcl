mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names    = ["us-east-1a", "us-east-1b", "us-east-1c"]
      zone_ids = ["use1-az1", "use1-az2", "use1-az3"]
    }
  }
}

run "computed_central_vpc_name_and_cidr_plan" {
  command = plan

  module {
    source = "./tests/fixtures/computed-central-vpcs"
  }
}
