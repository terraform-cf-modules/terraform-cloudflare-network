output "enabled" {
  description = "Whether this submodule created its resources."
  value       = var.enabled
}

output "byo_ip_prefixes" {
  description = "Full cloudflare_byo_ip_prefix objects, keyed by the keys of var.byo_ip_prefixes."
  value       = cloudflare_byo_ip_prefix.this
}

output "byo_ip_prefix_ids" {
  description = "BYOIP prefix IDs, keyed by the keys of var.byo_ip_prefixes."
  value       = { for k, v in cloudflare_byo_ip_prefix.this : k => v.id }
}

output "byo_ip_prefix_validation_tokens" {
  description = "Ownership validation tokens for each registered prefix, keyed by the keys of var.byo_ip_prefixes."
  value       = { for k, v in cloudflare_byo_ip_prefix.this : k => v.ownership_validation_token }
  sensitive   = true
}

output "address_maps" {
  description = "Full cloudflare_address_map objects, keyed by the keys of var.address_maps."
  value       = cloudflare_address_map.this
}

output "address_map_ids" {
  description = "Address map IDs, keyed by the keys of var.address_maps."
  value       = { for k, v in cloudflare_address_map.this : k => v.id }
}
