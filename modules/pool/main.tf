# -----------------------------------------------------------------------------
# Submodule: pool
#
#   cloudflare_load_balancer_pool  a named group of origins that a load balancer
#                                  can steer traffic to
#
# Pools are account scoped even though the load balancer that uses them is zone
# scoped, so a pool built here can back load balancers in several zones.
# -----------------------------------------------------------------------------

locals {
  pools = var.enabled ? var.pools : {}

  # origins is a list on the wire. Take it as a map so callers can add or remove
  # an origin without reordering the rest, then sort by key for a stable plan.
  pool_origins = {
    for pool_key, pool in local.pools : pool_key => [
      for origin_key in sort(keys(pool.origins)) : {
        address            = pool.origins[origin_key].address
        name               = coalesce(pool.origins[origin_key].name, origin_key)
        enabled            = pool.origins[origin_key].enabled
        port               = pool.origins[origin_key].port
        weight             = pool.origins[origin_key].weight
        flatten_cname      = pool.origins[origin_key].flatten_cname
        virtual_network_id = pool.origins[origin_key].virtual_network_id
        header = pool.origins[origin_key].host_header == null ? null : {
          host = [pool.origins[origin_key].host_header]
        }
      }
    ]
  }
}

resource "cloudflare_load_balancer_pool" "this" {
  for_each = local.pools

  account_id = var.account_id
  name       = coalesce(each.value.name, each.key)
  origins    = local.pool_origins[each.key]

  description        = each.value.description
  enabled            = each.value.enabled
  monitor            = each.value.monitor
  monitor_group      = each.value.monitor_group
  minimum_origins    = each.value.minimum_origins
  check_regions      = each.value.check_regions
  health_sources     = each.value.health_sources
  latitude           = each.value.latitude
  longitude          = each.value.longitude
  notification_email = each.value.notification_email

  origin_steering     = each.value.origin_steering
  load_shedding       = each.value.load_shedding
  notification_filter = each.value.notification_filter
}
