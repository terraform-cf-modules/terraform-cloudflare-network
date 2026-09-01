output "enabled" {
  description = "Whether this submodule created its resources."
  value       = var.enabled
}

output "gre_tunnels" {
  description = "Full cloudflare_magic_wan_gre_tunnel objects, keyed by the keys of var.gre_tunnels."
  value       = cloudflare_magic_wan_gre_tunnel.this
}

output "gre_tunnel_ids" {
  description = "GRE tunnel IDs, keyed by the keys of var.gre_tunnels."
  value       = { for k, v in cloudflare_magic_wan_gre_tunnel.this : k => v.id }
}

output "ipsec_tunnels" {
  description = "Full cloudflare_magic_wan_ipsec_tunnel objects, keyed by the keys of var.ipsec_tunnels. Marked sensitive because the object carries the pre shared key."
  value       = cloudflare_magic_wan_ipsec_tunnel.this
  sensitive   = true
}

output "ipsec_tunnel_ids" {
  description = "IPsec tunnel IDs, keyed by the keys of var.ipsec_tunnels."
  value       = { for k, v in cloudflare_magic_wan_ipsec_tunnel.this : k => v.id }
}

output "static_routes" {
  description = "Full cloudflare_magic_wan_static_route objects, keyed by the keys of var.static_routes."
  value       = cloudflare_magic_wan_static_route.this
}

output "static_route_ids" {
  description = "Static route IDs, keyed by the keys of var.static_routes."
  value       = { for k, v in cloudflare_magic_wan_static_route.this : k => v.id }
}
