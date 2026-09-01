output "enabled" {
  description = "Whether this submodule created its resources."
  value       = var.enabled
}

output "load_balancers" {
  description = "Full cloudflare_load_balancer objects, keyed by the keys of var.load_balancers."
  value       = cloudflare_load_balancer.this
}

output "load_balancer_ids" {
  description = "Load balancer IDs, keyed by the keys of var.load_balancers."
  value       = { for k, v in cloudflare_load_balancer.this : k => v.id }
}

output "hostnames" {
  description = "Resolved load balancer hostnames, keyed by the keys of var.load_balancers."
  value       = { for k, v in cloudflare_load_balancer.this : k => v.name }
}
