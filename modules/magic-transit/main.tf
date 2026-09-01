# -----------------------------------------------------------------------------
# Submodule: magic-transit
#
#   cloudflare_magic_transit_connector  the appliance that terminates a site
#   cloudflare_magic_transit_site       a physical location on the network
#   cloudflare_magic_transit_site_lan   LAN side interface on a site
#   cloudflare_magic_transit_site_wan   WAN side interface on a site
#   cloudflare_magic_transit_site_acl   allow policy between two LANs on a site
#
# Sites, LANs, WANs and ACLs reference each other by key inside this submodule,
# so Terraform derives the ordering from the references and no depends_on is
# needed.
#
# Magic Transit is an enterprise product. Every collection here defaults to
# empty so the module is inert on accounts that are not onboarded.
# -----------------------------------------------------------------------------

locals {
  connectors = var.enabled ? var.connectors : {}
  sites      = var.enabled ? var.sites : {}
  site_lans  = var.enabled ? var.site_lans : {}
  site_wans  = var.enabled ? var.site_wans : {}
  site_acls  = var.enabled ? var.site_acls : {}

  routed_subnets = {
    for lan_key, lan in local.site_lans : lan_key => [
      for subnet_key in sort(keys(lan.routed_subnets)) : {
        prefix   = lan.routed_subnets[subnet_key].prefix
        next_hop = lan.routed_subnets[subnet_key].next_hop
        nat = lan.routed_subnets[subnet_key].nat_static_prefix == null ? null : {
          static_prefix = lan.routed_subnets[subnet_key].nat_static_prefix
        }
      }
    ]
  }

  # dhcp_options is a list on the wire. Take it as a map keyed by the caller's
  # own label and sort for a stable plan.
  dhcp_options = {
    for lan_key, lan in local.site_lans : lan_key => [
      for option_key in sort(keys(try(lan.static_addressing.dhcp_server.dhcp_options, {}))) : {
        code  = lan.static_addressing.dhcp_server.dhcp_options[option_key].code
        type  = lan.static_addressing.dhcp_server.dhcp_options[option_key].type
        value = lan.static_addressing.dhcp_server.dhcp_options[option_key].value
      }
    ]
  }

  lan_static_addressing = {
    for lan_key, lan in local.site_lans : lan_key => (
      lan.static_addressing == null ? null : {
        address           = lan.static_addressing.address
        secondary_address = lan.static_addressing.secondary_address
        virtual_address   = lan.static_addressing.virtual_address
        dhcp_relay        = lan.static_addressing.dhcp_relay
        dhcp_server = lan.static_addressing.dhcp_server == null ? null : {
          dhcp_pool_start = lan.static_addressing.dhcp_server.dhcp_pool_start
          dhcp_pool_end   = lan.static_addressing.dhcp_server.dhcp_pool_end
          dns_server      = lan.static_addressing.dhcp_server.dns_server
          dns_servers     = lan.static_addressing.dhcp_server.dns_servers
          reservations    = lan.static_addressing.dhcp_server.reservations
          dhcp_options    = length(local.dhcp_options[lan_key]) > 0 ? local.dhcp_options[lan_key] : null
        }
      }
    )
  }
}

resource "cloudflare_magic_transit_connector" "this" {
  for_each = local.connectors

  account_id = var.account_id

  device = {
    id                = each.value.device_id
    serial_number     = each.value.device_serial_number
    provision_license = each.value.device_provision_license
  }

  activated                       = each.value.activated
  notes                           = each.value.notes
  timezone                        = each.value.timezone
  interrupt_window_hour_of_day    = each.value.interrupt_window_hour_of_day
  interrupt_window_duration_hours = each.value.interrupt_window_duration_hours
}

resource "cloudflare_magic_transit_site" "this" {
  for_each = local.sites

  account_id = var.account_id
  name       = coalesce(each.value.name, each.key)

  description = each.value.description
  ha_mode     = each.value.ha_mode
  location    = each.value.location

  connector_id = try(
    cloudflare_magic_transit_connector.this[each.value.connector_key].id,
    each.value.connector_id,
  )

  secondary_connector_id = try(
    cloudflare_magic_transit_connector.this[each.value.secondary_connector_key].id,
    each.value.secondary_connector_id,
  )
}

resource "cloudflare_magic_transit_site_lan" "this" {
  for_each = local.site_lans

  account_id = var.account_id
  site_id    = try(cloudflare_magic_transit_site.this[each.value.site_key].id, each.value.site_id)

  name           = each.value.name
  physport       = each.value.physport
  vlan_tag       = each.value.vlan_tag
  bond_id        = each.value.bond_id
  ha_link        = each.value.ha_link
  is_breakout    = each.value.is_breakout
  is_prioritized = each.value.is_prioritized

  nat = each.value.nat_static_prefix == null ? null : {
    static_prefix = each.value.nat_static_prefix
  }

  routed_subnets    = length(local.routed_subnets[each.key]) > 0 ? local.routed_subnets[each.key] : null
  static_addressing = local.lan_static_addressing[each.key]
}

resource "cloudflare_magic_transit_site_wan" "this" {
  for_each = local.site_wans

  account_id = var.account_id
  site_id    = try(cloudflare_magic_transit_site.this[each.value.site_key].id, each.value.site_id)
  physport   = each.value.physport

  name              = each.value.name
  priority          = each.value.priority
  vlan_tag          = each.value.vlan_tag
  static_addressing = each.value.static_addressing
}

resource "cloudflare_magic_transit_site_acl" "this" {
  for_each = local.site_acls

  account_id = var.account_id
  site_id    = try(cloudflare_magic_transit_site.this[each.value.site_key].id, each.value.site_id)
  name       = coalesce(each.value.name, each.key)

  description     = each.value.description
  protocols       = each.value.protocols
  forward_locally = each.value.forward_locally
  unidirectional  = each.value.unidirectional

  lan_1 = {
    lan_id      = try(cloudflare_magic_transit_site_lan.this[each.value.lan_1.lan_key].id, each.value.lan_1.lan_id)
    lan_name    = each.value.lan_1.lan_name
    ports       = each.value.lan_1.ports
    port_ranges = each.value.lan_1.port_ranges
    subnets     = each.value.lan_1.subnets
  }

  lan_2 = {
    lan_id      = try(cloudflare_magic_transit_site_lan.this[each.value.lan_2.lan_key].id, each.value.lan_2.lan_id)
    lan_name    = each.value.lan_2.lan_name
    ports       = each.value.lan_2.ports
    port_ranges = each.value.lan_2.port_ranges
    subnets     = each.value.lan_2.subnets
  }
}
