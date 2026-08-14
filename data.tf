# --- root/data.tf ---

locals {
  # ---------- CREATION OF RESOURCES ----------
  # Global Network & Core Network
  create_global_network = var.global_network == null ? false : length(keys(var.global_network)) > 0
  create_core_network   = var.core_network == null ? false : length(keys(var.core_network)) > 0
  # RAM Resources
  create_ram_resources = try(var.core_network.resource_share_name, null) != null
  # VPC types that support AWS Network Firewall integration
  network_firewall_vpc_types = ["inspection", "egress_with_inspection", "ingress_with_inspection"]
  # to share core network (global service) use AWS RAM from us-east-1 https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-share-network.html
  ram_global_region = "us-east-1"

  # ---------- CENTRAL VPC - SUBNETS CONFIGURATION ----------
  subnets = {
    inspection = {
      endpoints    = { name_prefix = "endpoints" }
      core_network = { appliance_mode_support = true }
    }
    egress = {
      public = { nat_gateway_configuration = "all_azs" }
      core_network = {
        appliance_mode_support  = false
        connect_to_public_natgw = true
      }
    }
    egress_with_inspection = {
      public       = { nat_gateway_configuration = "all_azs" }
      endpoints    = { connect_to_public_natgw = true }
      core_network = { appliance_mode_support = true }
    }
    shared_services = {
      core_network = { appliance_mode_support = false }
    }
    ingress = {
      public       = { nat_gateway_configuration = "none" }
      core_network = { appliance_mode_support = false }
    }
    ingress_with_inspection = {
      endpoints = { name_prefix = "endpoints" }
      public = {
        nat_gateway_configuration = "none"
        connect_to_igw            = false
      }
      core_network = { appliance_mode_support = false }
    }
  }

  # ---------- CENTRAL VPC - CORE NETWORK ROUTES CONFIGURATION ----------
  core_network_routes = {
    inspection              = { endpoints = "0.0.0.0/0" }
    egress                  = { public = var.ipv4_network_definition }
    egress_with_inspection  = { endpoints = var.ipv4_network_definition }
    ingress                 = { public = var.ipv4_network_definition }
    ingress_with_inspection = { public = var.ipv4_network_definition }
  }

  # ---------- AWS NETWORK FIREWALL ROUTING CONFIGURATION ----------
  routing_configuration = merge(local.routing_configuration_inspection, local.routing_configuration_egress, local.routing_configuration_ingress)

  # Routing configuration - Inspection VPC
  routing_configuration_inspection = { for k, v in module.central_vpcs : k => {
    centralized_inspection_without_egress = {
      connectivity_subnet_route_tables = { for i, j in v.rt_attributes_by_type_by_az.core_network : i => j.id }
    } }
    if var.central_vpcs[k].type == "inspection"
  }

  # Routing configuration - Egress VPC with inspection
  routing_configuration_egress = { for k, v in module.central_vpcs : k => {
    centralized_inspection_with_egress = {
      connectivity_subnet_route_tables = { for i, j in v.rt_attributes_by_type_by_az.core_network : i => j.id }
      public_subnet_route_tables       = { for i, j in v.rt_attributes_by_type_by_az.public : i => j.id }
      network_cidr_blocks              = startswith(try(var.ipv4_network_definition, ""), "pl-") ? data.aws_ec2_managed_prefix_list.ipv4_network_definition[0].entries[*].cidr : [var.ipv4_network_definition]
    } }
    if var.central_vpcs[k].type == "egress_with_inspection"
  }

  # Routing configuration - Ingress VPC with inspection
  routing_configuration_ingress = { for k, v in module.central_vpcs : k => {
    single_vpc = {
      igw_route_table               = aws_route_table.igw_route_table[k].id
      protected_subnet_route_tables = { for i, j in v.rt_attributes_by_type_by_az.public : i => j.id }
      protected_subnet_cidr_blocks  = module.public_subnet_cidrs[k].subnet_cidrs
    } }
    if var.central_vpcs[k].type == "ingress_with_inspection"
  }
}

# ---------- REFERENCED GLOBAL NETWORK ARN ----------
# Network Manager ARNs are global and can be derived from the caller account without
# introducing a read permission on the referenced Global Network.
data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

# ---------- PREFIX LIST TO LIST OF CIDRS ----------
# For AWS Network Firewall configuration (Egress with Inspection), a list of CIDRs is needed. If the IPv4 Network Definition passed is a prefix list, we need to translate
data "aws_ec2_managed_prefix_list" "ipv4_network_definition" {
  # The pl- selector must be known during planning because it controls count; use a literal or otherwise plan-known ID.
  count = startswith(coalesce(var.ipv4_network_definition, " "), "pl-") ? 1 : 0

  id = var.ipv4_network_definition
}

# ---------- SANITIZES TAGS ---------
module "tags" {
  source  = "aws-ia/label/aws"
  version = "0.0.6"

  tags = var.tags
}

module "global_network_tags" {
  source  = "aws-ia/label/aws"
  version = "0.0.6"

  tags = try(var.global_network.tags, {})
}

module "core_network_tags" {
  source  = "aws-ia/label/aws"
  version = "0.0.6"

  tags = try(var.core_network.tags, {})
}