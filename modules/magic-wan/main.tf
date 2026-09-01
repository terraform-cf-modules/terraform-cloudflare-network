# -----------------------------------------------------------------------------
# Submodule: magic-wan
#
#   cloudflare_magic_wan_gre_tunnel     GRE tunnel to a customer edge device
#   cloudflare_magic_wan_ipsec_tunnel   IPsec tunnel to a customer edge device
#   cloudflare_magic_wan_static_route   prefix to next hop routing entry
#
# Magic WAN is an enterprise product. Every collection here defaults to empty so
# the module is inert on accounts that are not onboarded.
# -----------------------------------------------------------------------------

locals {
  gre_tunnels   = var.enabled ? var.gre_tunnels : {}
  ipsec_tunnels = var.enabled ? var.ipsec_tunnels : {}
  static_routes = var.enabled ? var.static_routes : {}

  # health_check is a single nested attribute. Build it only when the caller set
  # at least one of its fields, so an unset tunnel keeps the Cloudflare default.
  gre_health_checks = {
    for k, t in local.gre_tunnels : k => (
      anytrue([
        t.health_check_enabled != null,
        t.health_check_direction != null,
        t.health_check_rate != null,
        t.health_check_type != null,
        t.health_check_target_saved != null,
        ]) ? {
        enabled   = t.health_check_enabled
        direction = t.health_check_direction
        rate      = t.health_check_rate
        type      = t.health_check_type
        target    = t.health_check_target_saved == null ? null : { saved = t.health_check_target_saved }
      } : null
    )
  }

  ipsec_health_checks = {
    for k, t in local.ipsec_tunnels : k => (
      anytrue([
        t.health_check_enabled != null,
        t.health_check_direction != null,
        t.health_check_rate != null,
        t.health_check_type != null,
        t.health_check_target_saved != null,
        ]) ? {
        enabled   = t.health_check_enabled
        direction = t.health_check_direction
        rate      = t.health_check_rate
        type      = t.health_check_type
        target    = t.health_check_target_saved == null ? null : { saved = t.health_check_target_saved }
      } : null
    )
  }
}

resource "cloudflare_magic_wan_gre_tunnel" "this" {
  for_each = local.gre_tunnels

  account_id              = var.account_id
  name                    = coalesce(each.value.name, each.key)
  cloudflare_gre_endpoint = each.value.cloudflare_gre_endpoint
  customer_gre_endpoint   = each.value.customer_gre_endpoint
  interface_address       = each.value.interface_address

  interface_address6       = each.value.interface_address6
  description              = each.value.description
  mtu                      = each.value.mtu
  ttl                      = each.value.ttl
  automatic_return_routing = each.value.automatic_return_routing

  health_check = local.gre_health_checks[each.key]
  bgp          = each.value.bgp
}

resource "cloudflare_magic_wan_ipsec_tunnel" "this" {
  for_each = local.ipsec_tunnels

  account_id          = var.account_id
  name                = coalesce(each.value.name, each.key)
  cloudflare_endpoint = each.value.cloudflare_endpoint
  interface_address   = each.value.interface_address

  customer_endpoint        = each.value.customer_endpoint
  interface_address6       = each.value.interface_address6
  description              = each.value.description
  psk                      = try(var.ipsec_tunnel_psks[each.key], null)
  replay_protection        = each.value.replay_protection
  automatic_return_routing = each.value.automatic_return_routing

  custom_remote_identities = each.value.custom_remote_fqdn_id == null ? null : {
    fqdn_id = each.value.custom_remote_fqdn_id
  }

  health_check = local.ipsec_health_checks[each.key]
  bgp          = each.value.bgp
}

resource "cloudflare_magic_wan_static_route" "this" {
  for_each = local.static_routes

  account_id = var.account_id
  prefix     = each.value.prefix
  nexthop    = each.value.nexthop
  priority   = each.value.priority

  description = each.value.description
  weight      = each.value.weight
  scope       = each.value.scope
}
