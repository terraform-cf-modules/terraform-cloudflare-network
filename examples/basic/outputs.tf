output "module" {
  description = "All outputs of the module under test."
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
