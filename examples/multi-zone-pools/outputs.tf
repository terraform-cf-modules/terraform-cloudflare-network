output "pool_ids" {
  description = "Pool IDs shared by both zones."
  value       = module.pool.pool_ids
}

output "monitor_ids" {
  description = "Monitor IDs backing the shared pools."
  value       = module.monitor.monitor_ids
}

output "primary_zone_hostnames" {
  description = "Load balancer hostnames in the primary zone."
  value       = module.primary_zone_load_balancer.hostnames
}

output "secondary_zone_hostnames" {
  description = "Load balancer hostnames in the secondary zone."
  value       = module.secondary_zone_load_balancer.hostnames
}
