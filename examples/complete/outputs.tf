output "module" {
  description = "All outputs of the load balancing root module."
  value       = module.this
}

output "load_balancer_hostnames" {
  description = "Hostnames served by the load balancers this example created."
  value       = module.this.hostnames
}

output "pool_ids" {
  description = "Pool IDs, keyed as they were declared."
  value       = module.this.pool_ids
}

output "monitor_ids" {
  description = "Monitor IDs, keyed as they were declared."
  value       = module.this.monitor_ids
}

output "spectrum_application_ids" {
  description = "Spectrum application IDs, keyed as they were declared."
  value       = module.spectrum.application_ids
}

output "address_map_ids" {
  description = "Address map IDs, keyed as they were declared. Empty unless var.enable_addressing is true."
  value       = module.addressing.address_map_ids
}

output "byo_ip_prefix_ids" {
  description = "BYOIP prefix IDs, keyed as they were declared. Empty unless var.enable_addressing is true."
  value       = module.addressing.byo_ip_prefix_ids
}

output "magic_network_monitoring_rule_ids" {
  description = "Magic Network Monitoring rule IDs. Empty unless var.enable_magic_network_monitoring is true."
  value       = module.monitoring.rule_ids
}

output "magic_wan_gre_tunnel_ids" {
  description = "Magic WAN GRE tunnel IDs. Empty unless var.enable_magic_wan is true."
  value       = module.magic_wan.gre_tunnel_ids
}

output "magic_wan_ipsec_tunnel_ids" {
  description = "Magic WAN IPsec tunnel IDs. Empty unless var.enable_magic_wan is true."
  value       = module.magic_wan.ipsec_tunnel_ids
}

output "magic_transit_site_ids" {
  description = "Magic Transit site IDs. Empty unless var.enable_magic_transit is true."
  value       = module.magic_transit.site_ids
}

output "magic_transit_connector_license_keys" {
  description = "Magic Transit connector license keys. Cloudflare returns these on creation only."
  value       = module.magic_transit.connector_license_keys
  sensitive   = true
}
