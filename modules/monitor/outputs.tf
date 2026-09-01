output "enabled" {
  description = "Whether this submodule created its resources."
  value       = var.enabled
}

output "monitors" {
  description = "Full cloudflare_load_balancer_monitor objects, keyed by the keys of var.monitors."
  value       = cloudflare_load_balancer_monitor.this
}

output "monitor_ids" {
  description = "Monitor IDs, keyed by the keys of var.monitors. Feed these into a pool's monitor input."
  value       = { for k, v in cloudflare_load_balancer_monitor.this : k => v.id }
}

output "monitor_groups" {
  description = "Full cloudflare_load_balancer_monitor_group objects, keyed by the keys of var.monitor_groups."
  value       = cloudflare_load_balancer_monitor_group.this
}

output "monitor_group_ids" {
  description = "Monitor group IDs, keyed by the keys of var.monitor_groups."
  value       = { for k, v in cloudflare_load_balancer_monitor_group.this : k => v.id }
}

output "healthchecks" {
  description = "Full cloudflare_healthcheck objects, keyed by the keys of var.healthchecks."
  value       = cloudflare_healthcheck.this
}

output "healthcheck_ids" {
  description = "Health check IDs, keyed by the keys of var.healthchecks."
  value       = { for k, v in cloudflare_healthcheck.this : k => v.id }
}
