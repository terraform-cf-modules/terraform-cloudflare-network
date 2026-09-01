locals {
  # Single switch consulted by every resource in this module.
  enabled = var.enabled

  # Reference resolution.
  #
  # Callers name monitors and pools by their map key rather than by a Cloudflare
  # ID that does not exist until apply. These lookup tables translate a key to
  # the created ID and leave anything else untouched, so a field may hold either
  # a key from this module or a literal ID for an object managed elsewhere.
  monitor_ids       = module.monitor.monitor_ids
  monitor_group_ids = module.monitor.monitor_group_ids
  pool_ids          = module.pool.pool_ids

  pools = {
    for pool_key, pool in var.pools : pool_key => merge(pool, {
      monitor       = pool.monitor == null ? null : lookup(local.monitor_ids, pool.monitor, pool.monitor)
      monitor_group = pool.monitor_group == null ? null : lookup(local.monitor_group_ids, pool.monitor_group, pool.monitor_group)
    })
  }

  load_balancers = {
    for lb_key, lb in var.load_balancers : lb_key => merge(lb, {
      default_pools = [for ref in lb.default_pools : lookup(local.pool_ids, ref, ref)]
      fallback_pool = lookup(local.pool_ids, lb.fallback_pool, lb.fallback_pool)

      region_pools  = local.resolved_region_pools[lb_key]
      country_pools = local.resolved_country_pools[lb_key]
      pop_pools     = local.resolved_pop_pools[lb_key]

      rules = {
        for rule_key, rule in lb.rules : rule_key => merge(rule, {
          overrides = rule.overrides == null ? null : merge(rule.overrides, {
            default_pools = rule.overrides.default_pools == null ? null : [
              for ref in rule.overrides.default_pools : lookup(local.pool_ids, ref, ref)
            ]
            fallback_pool = rule.overrides.fallback_pool == null ? null : lookup(
              local.pool_ids, rule.overrides.fallback_pool, rule.overrides.fallback_pool
            )
            region_pools  = local.resolved_rule_region_pools["${lb_key}/${rule_key}"]
            country_pools = local.resolved_rule_country_pools["${lb_key}/${rule_key}"]
            pop_pools     = local.resolved_rule_pop_pools["${lb_key}/${rule_key}"]
          })
        })
      }
    })
  }

  # Geo steering maps hold an ordered list of pool references per region,
  # country or Cloudflare PoP. Resolved separately to keep the expression above
  # readable.
  resolved_region_pools = {
    for lb_key, lb in var.load_balancers : lb_key => (
      lb.region_pools == null ? null : {
        for region, refs in lb.region_pools : region => [for ref in refs : lookup(local.pool_ids, ref, ref)]
      }
    )
  }

  resolved_country_pools = {
    for lb_key, lb in var.load_balancers : lb_key => (
      lb.country_pools == null ? null : {
        for country, refs in lb.country_pools : country => [for ref in refs : lookup(local.pool_ids, ref, ref)]
      }
    )
  }

  resolved_pop_pools = {
    for lb_key, lb in var.load_balancers : lb_key => (
      lb.pop_pools == null ? null : {
        for pop, refs in lb.pop_pools : pop => [for ref in refs : lookup(local.pool_ids, ref, ref)]
      }
    )
  }

  # Same three maps again, this time for the geo steering overrides that a
  # single load balancer rule can carry. Flattened to one map keyed
  # "<load balancer key>/<rule key>".
  rule_pairs = merge([
    for lb_key, lb in var.load_balancers : {
      for rule_key, rule in lb.rules : "${lb_key}/${rule_key}" => rule
    }
  ]...)

  resolved_rule_region_pools = {
    for pair_key, rule in local.rule_pairs : pair_key => (
      try(rule.overrides.region_pools, null) == null ? null : {
        for region, refs in rule.overrides.region_pools : region => [for ref in refs : lookup(local.pool_ids, ref, ref)]
      }
    )
  }

  resolved_rule_country_pools = {
    for pair_key, rule in local.rule_pairs : pair_key => (
      try(rule.overrides.country_pools, null) == null ? null : {
        for country, refs in rule.overrides.country_pools : country => [for ref in refs : lookup(local.pool_ids, ref, ref)]
      }
    )
  }

  resolved_rule_pop_pools = {
    for pair_key, rule in local.rule_pairs : pair_key => (
      try(rule.overrides.pop_pools, null) == null ? null : {
        for pop, refs in rule.overrides.pop_pools : pop => [for ref in refs : lookup(local.pool_ids, ref, ref)]
      }
    )
  }
}
