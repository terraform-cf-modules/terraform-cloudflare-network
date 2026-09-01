# -----------------------------------------------------------------------------
# Wrapper: create many instances of the root module from a single map.
#
# One instance per zone is the usual reason to reach for this. Pools and
# monitors are account scoped, so if several zones share the same origins it is
# usually better to build the pools once with modules/pool and pass their IDs
# into each load balancer rather than duplicating them here.
#
#   module "zones" {
#     source = "terraform-cf-modules/network/cloudflare//wrappers"
#
#     defaults = {
#       account_id = var.account_id
#
#       monitors = {
#         http = { type = "http", path = "/healthz" }
#       }
#     }
#
#     items = {
#       example_com = {
#         zone_id = var.example_com_zone_id
#
#         pools = {
#           primary = {
#             monitor = "http"
#             origins = { a = { address = "192.0.2.10" } }
#           }
#         }
#
#         load_balancers = {
#           "www.example.com" = {
#             default_pools = ["primary"]
#             fallback_pool = "primary"
#           }
#         }
#       }
#     }
#   }
# -----------------------------------------------------------------------------

module "wrapper" {
  source = "../"

  for_each = var.items

  enabled    = try(each.value.enabled, var.defaults.enabled, true)
  account_id = try(each.value.account_id, var.defaults.account_id, null)
  zone_id    = try(each.value.zone_id, var.defaults.zone_id, null)

  monitors       = try(each.value.monitors, var.defaults.monitors, {})
  monitor_groups = try(each.value.monitor_groups, var.defaults.monitor_groups, {})
  healthchecks   = try(each.value.healthchecks, var.defaults.healthchecks, {})

  pools          = try(each.value.pools, var.defaults.pools, {})
  load_balancers = try(each.value.load_balancers, var.defaults.load_balancers, {})
}
