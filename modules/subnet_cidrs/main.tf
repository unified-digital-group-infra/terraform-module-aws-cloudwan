# --- modules/subnet_cidrs/main.tf ---

locals {
  # List of Availability Zone IDs from map
  azs = keys(var.subnet_ids)
  # List of Subnet IDs from map
  subnet_ids = values(var.subnet_ids)
}

data "aws_subnet" "subnet" {
  count = length(var.subnet_ids)

  id = local.subnet_ids[count.index]

  lifecycle {
    precondition {
      condition     = tonumber(var.number_azs) == length(var.subnet_ids)
      error_message = "number_azs must equal the number of entries in subnet_ids so every Availability Zone has exactly one subnet lookup."
    }
  }
}