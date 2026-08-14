# --- root/outputs.tf ---

# GLOBAL NETORK
output "global_network" {
  value       = local.create_global_network ? aws_networkmanager_global_network.global_network[0] : null
  description = "Global Network. Full output of aws_networkmanager_global_network."

  precondition {
    condition     = !(local.create_global_network && var.global_network_id != null)
    error_message = "Set only one of var.global_network or var.global_network_id; defining both is ambiguous."
  }

  precondition {
    condition     = !local.create_core_network || local.create_global_network || var.global_network_id != null
    error_message = "Creating var.core_network requires exactly one Global Network source: var.global_network or var.global_network_id."
  }
}

# CORE NETWORK
output "core_network" {
  value       = local.create_core_network ? aws_networkmanager_core_network.core_network[0] : null
  description = "Core Network. Full output of aws_networkmanager_core_network."

  precondition {
    condition     = !(local.create_core_network && var.core_network_arn != null)
    error_message = "Set only one of var.core_network or var.core_network_arn; defining both is ambiguous."
  }

  precondition {
    condition     = length(keys(var.central_vpcs)) == 0 || local.create_core_network || var.core_network_arn != null
    error_message = "Using var.central_vpcs requires exactly one Core Network source: var.core_network or var.core_network_arn."
  }
}

# RESOURCE SHARE
output "ram_resource_share" {
  value       = local.create_ram_resources && local.create_core_network ? aws_ram_resource_share.resource_share[0] : null
  description = "Resource Access Manager (RAM) Resource Share. Full output of aws_ram_resource_share."
}

# CENTRAL VPCS
output "central_vpcs" {
  value       = try(module.central_vpcs, null)
  description = "Central VPC information. Full output of VPC module - https://registry.terraform.io/modules/aws-ia/vpc/aws/latest."
}

# AWS NETWORK FIREWALL
output "aws_network_firewall" {
  value       = { for k, v in try(module.network_firewall, {}) : k => v.aws_network_firewall }
  description = "AWS Network Firewall. Full output of aws_networkfirewall_firewall."

  precondition {
    condition     = alltrue([for k in keys(try(var.aws_network_firewall, {})) : contains(keys(var.central_vpcs), k)])
    error_message = "Each key in var.aws_network_firewall must match a key in var.central_vpcs."
  }

  precondition {
    condition = alltrue([
      for k in keys(try(var.aws_network_firewall, {})) :
      !contains(keys(var.central_vpcs), k) || contains(local.network_firewall_vpc_types, try(var.central_vpcs[k].type, ""))
    ])
    error_message = "Each var.aws_network_firewall entry must reference a central VPC of type inspection, egress_with_inspection, or ingress_with_inspection."
  }
}

# STABLE TIER 1 HANDLES
output "global_network_id" {
  value       = local.create_global_network ? aws_networkmanager_global_network.global_network[0].id : var.global_network_id
  description = "Global Network ID, whether created by this module or supplied by the caller."
}

output "global_network_arn" {
  value = local.create_global_network ? aws_networkmanager_global_network.global_network[0].arn : (
    var.global_network_id == null ? null : format(
      "arn:%s:networkmanager::%s:global-network/%s",
      data.aws_partition.current.partition,
      data.aws_caller_identity.current.account_id,
      var.global_network_id
    )
  )
  description = "Global Network ARN, whether created by this module or derived for a caller-supplied ID."
}

output "core_network_id" {
  value       = local.create_core_network ? aws_networkmanager_core_network.core_network[0].id : try(split("/", var.core_network_arn)[1], null)
  description = "Core Network ID, whether created by this module or derived from a caller-supplied ARN."
}

output "core_network_arn" {
  value       = local.create_core_network ? aws_networkmanager_core_network.core_network[0].arn : var.core_network_arn
  description = "Core Network ARN, whether created by this module or supplied by the caller."
}

output "ram_resource_share_arn" {
  value       = local.create_ram_resources && local.create_core_network ? aws_ram_resource_share.resource_share[0].arn : null
  description = "RAM Resource Share ARN when this module creates the share."
}

output "central_vpc_ids" {
  value       = { for key, vpc in module.central_vpcs : key => vpc.vpc_attributes.id }
  description = "Central VPC IDs keyed by the caller-owned central_vpcs key."
}

output "core_network_attachment_ids" {
  value       = { for key, vpc in module.central_vpcs : key => try(vpc.core_network_attachment.id, null) }
  description = "Core Network VPC attachment IDs keyed by the caller-owned central_vpcs key."
}
