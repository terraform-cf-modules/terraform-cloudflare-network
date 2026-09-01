# -----------------------------------------------------------------------------
# Submodule: monitoring
#
#   cloudflare_magic_network_monitoring_configuration  account wide flow
#                                                      collection settings
#   cloudflare_magic_network_monitoring_rule           threshold, zscore and
#                                                      advanced DDoS alert rules
#
# Magic Network Monitoring analyses NetFlow or sFlow exported by your routers.
# The configuration is a singleton per account, so it is a count based resource
# rather than a keyed map.
# -----------------------------------------------------------------------------

locals {
  create_configuration = var.enabled && var.configuration != null
  rules                = var.enabled ? var.rules : {}

  warp_devices = local.create_configuration ? [
    for device_key in sort(keys(var.configuration.warp_devices)) : {
      id        = var.configuration.warp_devices[device_key].id
      name      = var.configuration.warp_devices[device_key].name
      router_ip = var.configuration.warp_devices[device_key].router_ip
    }
  ] : []
}

resource "cloudflare_magic_network_monitoring_configuration" "this" {
  count = local.create_configuration ? 1 : 0

  account_id = var.account_id
  name       = var.configuration.name

  default_sampling = var.configuration.default_sampling
  router_ips       = var.configuration.router_ips
  warp_devices     = length(local.warp_devices) > 0 ? local.warp_devices : null
}

resource "cloudflare_magic_network_monitoring_rule" "this" {
  for_each = local.rules

  account_id              = var.account_id
  name                    = coalesce(each.value.name, each.key)
  type                    = each.value.type
  prefixes                = each.value.prefixes
  automatic_advertisement = each.value.automatic_advertisement

  bandwidth_threshold = each.value.bandwidth_threshold
  packet_threshold    = each.value.packet_threshold
  duration            = each.value.duration
  prefix_match        = each.value.prefix_match
  zscore_sensitivity  = each.value.zscore_sensitivity
  zscore_target       = each.value.zscore_target
}
