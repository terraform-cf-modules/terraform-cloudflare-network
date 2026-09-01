# -----------------------------------------------------------------------------
# Submodule: spectrum
#
#   cloudflare_spectrum_application  proxy arbitrary TCP and UDP traffic through
#                                    Cloudflare, not just HTTP
#
# The provider types origin_port as a dynamic value: an integer for one port, a
# string for a range. A Terraform object type constraint unifies every element
# of a map to one type, so a single map input cannot carry both. The two
# resource blocks below split the applications by which form they use, and the
# outputs merge them back into one map keyed as the caller supplied it.
# -----------------------------------------------------------------------------

locals {
  applications = var.enabled ? var.applications : {}

  single_port_applications = {
    for k, a in local.applications : k => a if a.origin_port_range == null
  }

  port_range_applications = {
    for k, a in local.applications : k => a if a.origin_port_range != null
  }
}

resource "cloudflare_spectrum_application" "this" {
  for_each = local.single_port_applications

  zone_id  = var.zone_id
  protocol = each.value.protocol
  dns      = each.value.dns

  origin_direct = each.value.origin_direct
  origin_dns    = each.value.origin_dns
  origin_port   = each.value.origin_port

  edge_ips           = each.value.edge_ips
  argo_smart_routing = each.value.argo_smart_routing
  ip_firewall        = each.value.ip_firewall
  proxy_protocol     = each.value.proxy_protocol
  tls                = each.value.tls
  traffic_type       = each.value.traffic_type
  virtual_network_id = each.value.virtual_network_id
}

resource "cloudflare_spectrum_application" "port_range" {
  for_each = local.port_range_applications

  zone_id  = var.zone_id
  protocol = each.value.protocol
  dns      = each.value.dns

  origin_direct = each.value.origin_direct
  origin_dns    = each.value.origin_dns
  origin_port   = each.value.origin_port_range

  edge_ips           = each.value.edge_ips
  argo_smart_routing = each.value.argo_smart_routing
  ip_firewall        = each.value.ip_firewall
  proxy_protocol     = each.value.proxy_protocol
  tls                = each.value.tls
  traffic_type       = each.value.traffic_type
  virtual_network_id = each.value.virtual_network_id
}
