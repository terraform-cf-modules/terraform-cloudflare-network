output "enabled" {
  description = "Whether this submodule created its resources."
  value       = var.enabled
}

output "connectors" {
  description = "Full cloudflare_magic_transit_connector objects, keyed by the keys of var.connectors. Marked sensitive because the object carries the connector license key."
  value       = cloudflare_magic_transit_connector.this
  sensitive   = true
}

output "connector_ids" {
  description = "Connector IDs, keyed by the keys of var.connectors."
  value       = { for k, v in cloudflare_magic_transit_connector.this : k => v.id }
}

output "connector_license_keys" {
  description = "License keys returned when each connector was created. Cloudflare returns these once, on creation only."
  value       = { for k, v in cloudflare_magic_transit_connector.this : k => v.license_key }
  sensitive   = true
}

output "sites" {
  description = "Full cloudflare_magic_transit_site objects, keyed by the keys of var.sites."
  value       = cloudflare_magic_transit_site.this
}

output "site_ids" {
  description = "Site IDs, keyed by the keys of var.sites."
  value       = { for k, v in cloudflare_magic_transit_site.this : k => v.id }
}

output "site_lans" {
  description = "Full cloudflare_magic_transit_site_lan objects, keyed by the keys of var.site_lans."
  value       = cloudflare_magic_transit_site_lan.this
}

output "site_lan_ids" {
  description = "LAN IDs, keyed by the keys of var.site_lans."
  value       = { for k, v in cloudflare_magic_transit_site_lan.this : k => v.id }
}

output "site_wans" {
  description = "Full cloudflare_magic_transit_site_wan objects, keyed by the keys of var.site_wans."
  value       = cloudflare_magic_transit_site_wan.this
}

output "site_wan_ids" {
  description = "WAN IDs, keyed by the keys of var.site_wans."
  value       = { for k, v in cloudflare_magic_transit_site_wan.this : k => v.id }
}

output "site_acls" {
  description = "Full cloudflare_magic_transit_site_acl objects, keyed by the keys of var.site_acls."
  value       = cloudflare_magic_transit_site_acl.this
}

output "site_acl_ids" {
  description = "ACL IDs, keyed by the keys of var.site_acls."
  value       = { for k, v in cloudflare_magic_transit_site_acl.this : k => v.id }
}
