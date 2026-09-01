# The submodules return empty maps when disabled, so no try() guard is needed
# here. try() would also make every value unknown at plan time, which stops
# terraform test asserting on them.

output "enabled" {
  description = "Whether this module created its resources."
  value       = local.enabled
}

output "monitors" {
  description = "Full cloudflare_load_balancer_monitor objects, keyed by the keys of var.monitors."
  value       = module.monitor.monitors
}

output "monitor_ids" {
  description = "Monitor IDs, keyed by the keys of var.monitors."
  value       = module.monitor.monitor_ids
}

output "monitor_groups" {
  description = "Full cloudflare_load_balancer_monitor_group objects, keyed by the keys of var.monitor_groups."
  value       = module.monitor.monitor_groups
}

output "monitor_group_ids" {
  description = "Monitor group IDs, keyed by the keys of var.monitor_groups."
  value       = module.monitor.monitor_group_ids
}

output "healthchecks" {
  description = "Full cloudflare_healthcheck objects, keyed by the keys of var.healthchecks."
  value       = module.monitor.healthchecks
}

output "healthcheck_ids" {
  description = "Health check IDs, keyed by the keys of var.healthchecks."
  value       = module.monitor.healthcheck_ids
}

output "pools" {
  description = "Full cloudflare_load_balancer_pool objects, keyed by the keys of var.pools."
  value       = module.pool.pools
}

output "pool_ids" {
  description = "Pool IDs, keyed by the keys of var.pools."
  value       = module.pool.pool_ids
}

output "load_balancers" {
  description = "Full cloudflare_load_balancer objects, keyed by the keys of var.load_balancers."
  value       = module.load_balancer.load_balancers
}

output "load_balancer_ids" {
  description = "Load balancer IDs, keyed by the keys of var.load_balancers."
  value       = module.load_balancer.load_balancer_ids
}

output "hostnames" {
  description = "Resolved load balancer hostnames, keyed by the keys of var.load_balancers."
  value       = module.load_balancer.hostnames
}
