mock_provider "aws" {}
run "central_vpc_and_firewall_tags_use_their_own_inputs" {
  command = plan

  assert {
    condition = (
      length(regexall("module\\.tags\\.tags_aws,\\n    try\\(each\\.value\\.tags, \\{\\}\\)", file("${path.module}/main.tf"))) == 1 &&
      length(regexall("module\\.tags\\.tags_aws,\\n    try\\(var\\.aws_network_firewall\\[each\\.key\\]\\.tags, \\{\\}\\)", file("${path.module}/main.tf"))) == 1
    )
    error_message = "Productive module inputs must merge global tags with each Central VPC's tags and, separately, each Network Firewall's tags."
  }
}
