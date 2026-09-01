# -----------------------------------------------------------------------------
# Module: Cloudflare Network
# Load balancing, health monitors, Spectrum applications, Magic WAN, and Magic Transit.
#
# The root module composes the common case: a working load balancer. It creates
# monitors, then the pools that reference them, then the load balancers that
# steer across those pools, resolving map keys to Cloudflare IDs along the way.
#
# The remaining building blocks are standalone and are consumed with the double
# slash source syntax:
#
#   source = "terraform-cf-modules/network/cloudflare//modules/<name>"
#
#   spectrum        cloudflare_spectrum_application
#   magic-wan       GRE and IPsec tunnels, static routes
#   magic-transit   sites, LANs, WANs, ACLs, connectors
#   addressing      BYOIP prefixes and address maps
#   monitoring      Magic Network Monitoring configuration and rules
#
# Ordering is implied by references: pools consume monitor IDs and load
# balancers consume pool IDs, so Terraform builds the graph without depends_on.
# -----------------------------------------------------------------------------

module "monitor" {
  source = "./modules/monitor"

  enabled    = local.enabled
  account_id = var.account_id
  zone_id    = var.zone_id

  monitors       = var.monitors
  monitor_groups = var.monitor_groups
  healthchecks   = var.healthchecks
}

module "pool" {
  source = "./modules/pool"

  enabled    = local.enabled
  account_id = var.account_id

  pools = local.pools
}

module "load_balancer" {
  source = "./modules/load-balancer"

  enabled = local.enabled
  zone_id = var.zone_id

  load_balancers = local.load_balancers
}
