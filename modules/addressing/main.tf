# -----------------------------------------------------------------------------
# Submodule: addressing
#
#   cloudflare_byo_ip_prefix  register a customer owned prefix for Cloudflare to
#                             advertise under a given ASN
#   cloudflare_address_map    pin account owned IPs to zones or to the account
#
# Both are account scoped and both need Cloudflare side approval or provisioning
# before traffic actually moves. Terraform registers the intent, it does not
# complete the onboarding.
# -----------------------------------------------------------------------------

locals {
  byo_ip_prefixes = var.enabled ? var.byo_ip_prefixes : {}
  address_maps    = var.enabled ? var.address_maps : {}

  address_map_memberships = {
    for map_key, address_map in local.address_maps : map_key => [
      for member_key in sort(keys(address_map.memberships)) : {
        identifier = address_map.memberships[member_key].identifier
        kind       = address_map.memberships[member_key].kind
      }
    ]
  }
}

resource "cloudflare_byo_ip_prefix" "this" {
  for_each = local.byo_ip_prefixes

  account_id = var.account_id
  cidr       = each.value.cidr
  asn        = each.value.asn

  description           = each.value.description
  delegate_loa_creation = each.value.delegate_loa_creation
  loa_document_id       = each.value.loa_document_id
}

resource "cloudflare_address_map" "this" {
  for_each = local.address_maps

  account_id = var.account_id

  description = each.value.description
  enabled     = each.value.enabled
  default_sni = each.value.default_sni
  ips         = each.value.ips
  memberships = length(each.value.memberships) > 0 ? local.address_map_memberships[each.key] : null
}
