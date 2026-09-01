output "enabled" {
  description = "Whether this submodule created its resources."
  value       = var.enabled
}

output "pools" {
  description = "Full cloudflare_load_balancer_pool objects, keyed by the keys of var.pools."
  value       = cloudflare_load_balancer_pool.this
}

output "pool_ids" {
  description = "Pool IDs, keyed by the keys of var.pools. Feed these into a load balancer's default_pools or fallback_pool."
  value       = { for k, v in cloudflare_load_balancer_pool.this : k => v.id }
}

output "pool_names" {
  description = "Resolved pool names, keyed by the keys of var.pools."
  value       = { for k, v in cloudflare_load_balancer_pool.this : k => v.name }
}
