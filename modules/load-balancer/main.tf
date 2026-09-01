# -----------------------------------------------------------------------------
# Submodule: load-balancer
#
#   cloudflare_load_balancer  the zone scoped hostname that steers traffic
#                             across account scoped pools
#
# The pools referenced here must already exist. Build them with
# modules/pool and pass the resulting IDs in, or use the root module, which
# wires monitors, pools and load balancers together by key.
# -----------------------------------------------------------------------------

locals {
  load_balancers = var.enabled ? var.load_balancers : {}

  # rules is an ordered list on the wire. Taken as a map so a caller can add or
  # remove one without reordering the rest, then sorted by key for a stable plan.
  # Priority, when set, is what actually decides evaluation order at the edge.
  load_balancer_rules = {
    for lb_key, lb in local.load_balancers : lb_key => [
      for rule_key in sort(keys(lb.rules)) : {
        name           = coalesce(lb.rules[rule_key].name, rule_key)
        condition      = lb.rules[rule_key].condition
        disabled       = lb.rules[rule_key].disabled
        priority       = lb.rules[rule_key].priority
        terminates     = lb.rules[rule_key].terminates
        fixed_response = lb.rules[rule_key].fixed_response
        overrides      = lb.rules[rule_key].overrides
      }
    ]
  }
}

resource "cloudflare_load_balancer" "this" {
  for_each = local.load_balancers

  zone_id       = var.zone_id
  name          = coalesce(each.value.name, each.key)
  default_pools = each.value.default_pools
  fallback_pool = each.value.fallback_pool

  description = each.value.description
  enabled     = each.value.enabled
  proxied     = each.value.proxied
  ttl         = each.value.ttl
  networks    = each.value.networks

  steering_policy      = each.value.steering_policy
  session_affinity     = each.value.session_affinity
  session_affinity_ttl = each.value.session_affinity_ttl

  region_pools  = each.value.region_pools
  country_pools = each.value.country_pools
  pop_pools     = each.value.pop_pools

  # Nested attributes in provider v5, not blocks. The variable object types
  # mirror the schema exactly so they pass straight through.
  adaptive_routing            = each.value.adaptive_routing
  location_strategy           = each.value.location_strategy
  random_steering             = each.value.random_steering
  session_affinity_attributes = each.value.session_affinity_attributes

  rules = length(each.value.rules) > 0 ? local.load_balancer_rules[each.key] : null
}
