output "enabled" {
  description = "Whether this submodule created its resources."
  value       = var.enabled
}

output "configuration" {
  description = "The cloudflare_magic_network_monitoring_configuration object, or null when var.configuration is unset."
  value       = one(cloudflare_magic_network_monitoring_configuration.this)
}

output "rules" {
  description = "Full cloudflare_magic_network_monitoring_rule objects, keyed by the keys of var.rules."
  value       = cloudflare_magic_network_monitoring_rule.this
}

output "rule_ids" {
  description = "Magic Network Monitoring rule IDs, keyed by the keys of var.rules."
  value       = { for k, v in cloudflare_magic_network_monitoring_rule.this : k => v.id }
}
