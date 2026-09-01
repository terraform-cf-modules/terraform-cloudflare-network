# -----------------------------------------------------------------------------
# Submodule: monitor
#
# Health checking for load balancing, plus the standalone zone level Health
# Checks product.
#
#   cloudflare_load_balancer_monitor        account scoped probe definition
#   cloudflare_load_balancer_monitor_group  bundle of monitors judged together
#   cloudflare_healthcheck                  zone scoped standalone health check
# -----------------------------------------------------------------------------

locals {
  monitors       = var.enabled ? var.monitors : {}
  monitor_groups = var.enabled ? var.monitor_groups : {}
  healthchecks   = var.enabled ? var.healthchecks : {}

  # Monitor group members arrive as a map so a caller can add or remove one
  # without shifting the others. Sort by key so the list handed to the provider
  # is stable across plans.
  monitor_group_members = {
    for group_key, group in local.monitor_groups : group_key => [
      for member_key in sort(keys(group.members)) : {
        monitor_id = coalesce(
          try(cloudflare_load_balancer_monitor.this[group.members[member_key].monitor_key].id, null),
          group.members[member_key].monitor_id,
        )
        enabled         = group.members[member_key].enabled
        monitoring_only = group.members[member_key].monitoring_only
        must_be_healthy = group.members[member_key].must_be_healthy
      }
    ]
  }
}

resource "cloudflare_load_balancer_monitor" "this" {
  for_each = local.monitors

  account_id = var.account_id
  type       = each.value.type

  description      = each.value.description
  method           = each.value.method
  path             = each.value.path
  port             = each.value.port
  interval         = each.value.interval
  timeout          = each.value.timeout
  retries          = each.value.retries
  consecutive_up   = each.value.consecutive_up
  consecutive_down = each.value.consecutive_down
  expected_body    = each.value.expected_body
  expected_codes   = each.value.expected_codes
  follow_redirects = each.value.follow_redirects
  allow_insecure   = each.value.allow_insecure
  probe_zone       = each.value.probe_zone
  header           = each.value.header
}

resource "cloudflare_load_balancer_monitor_group" "this" {
  for_each = local.monitor_groups

  account_id  = var.account_id
  description = each.value.description
  members     = local.monitor_group_members[each.key]
}

resource "cloudflare_healthcheck" "this" {
  for_each = local.healthchecks

  zone_id = var.zone_id
  name    = coalesce(each.value.name, each.key)
  address = each.value.address
  type    = each.value.type

  description           = each.value.description
  check_regions         = each.value.check_regions
  consecutive_fails     = each.value.consecutive_fails
  consecutive_successes = each.value.consecutive_successes
  interval              = each.value.interval
  retries               = each.value.retries
  timeout               = each.value.timeout
  suspended             = each.value.suspended

  # http_config and tcp_config are nested attributes in provider v5, not blocks,
  # so they are assigned as objects. The variable object types mirror the schema
  # exactly, which lets them pass straight through.
  http_config = each.value.http_config
  tcp_config  = each.value.tcp_config
}
