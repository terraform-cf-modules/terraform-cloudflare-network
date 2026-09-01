# Submodule: load-balancer

Load balancers.

Creates `cloudflare_load_balancer`: the zone scoped hostname that steers traffic across account scoped pools.

Every pool reference here is a Cloudflare pool ID. To reference pools by key instead, use the root module.

`steering_policy` decides which pool map is consulted:

| Policy | Pools used |
|--------|-----------|
| `off` (or unset) | `default_pools` in order |
| `geo` | `pop_pools`, then `country_pools`, then `region_pools`, falling back to `default_pools` |
| `random` | any pool, weighted by `random_steering` |
| `dynamic_latency` | closest pool in `default_pools` by round trip time, needs pool health checks |
| `proximity` | closest pool by the pool's own latitude and longitude |
| `least_outstanding_requests` / `least_connections` | pool with the least load, weighted by `random_steering` |

`rules` is a BETA field in the Cloudflare API and is not generally available. It is taken as a map and sorted by
key so entries can be added or removed without reordering; `priority` is what actually decides evaluation order
at the edge. A rule sets either `fixed_response` or `overrides`, never both.

## Usage

```hcl
module "load_balancer" {
  source  = "terraform-cf-modules/network/cloudflare//modules/load-balancer"
  version = "~> 0.1"

  enabled = true
  zone_id = var.zone_id

  load_balancers = {
    "www.example.com" = {
      default_pools   = [module.pool.pool_ids["europe"], module.pool.pool_ids["north_america"]]
      fallback_pool   = module.pool.pool_ids["north_america"]
      proxied         = true
      steering_policy = "geo"

      region_pools  = { WEU = [module.pool.pool_ids["europe"]] }
      country_pools = { GB = [module.pool.pool_ids["europe"]] }

      session_affinity     = "cookie"
      session_affinity_ttl = 3600

      adaptive_routing = { failover_across_pools = true }
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Whether to create the resources managed by this submodule. | `bool` | `true` | no |
| <a name="input_load_balancers"></a> [load\_balancers](#input\_load\_balancers) | Load balancers to create, keyed by a stable identifier. The map key becomes the DNS hostname unless the object<br/>sets name explicitly.<br/><br/>default\_pools and fallback\_pool take pool IDs. region\_pools, country\_pools and pop\_pools map a region code,<br/>two letter country code or Cloudflare PoP code to an ordered list of pool IDs and are only consulted when<br/>steering\_policy is geo. The root module of this repository resolves pool keys to IDs for you. | <pre>map(object({<br/>    name          = optional(string)<br/>    default_pools = list(string)<br/>    fallback_pool = string<br/><br/>    description = optional(string)<br/>    enabled     = optional(bool, true)<br/>    proxied     = optional(bool)<br/>    ttl         = optional(number)<br/>    networks    = optional(list(string))<br/><br/>    steering_policy      = optional(string)<br/>    session_affinity     = optional(string)<br/>    session_affinity_ttl = optional(number)<br/><br/>    region_pools  = optional(map(list(string)))<br/>    country_pools = optional(map(list(string)))<br/>    pop_pools     = optional(map(list(string)))<br/><br/>    adaptive_routing = optional(object({<br/>      failover_across_pools = optional(bool)<br/>    }))<br/><br/>    location_strategy = optional(object({<br/>      mode       = optional(string)<br/>      prefer_ecs = optional(string)<br/>    }))<br/><br/>    random_steering = optional(object({<br/>      default_weight = optional(number)<br/>      pool_weights   = optional(map(number))<br/>    }))<br/><br/>    session_affinity_attributes = optional(object({<br/>      drain_duration         = optional(number)<br/>      headers                = optional(list(string))<br/>      require_all_headers    = optional(bool)<br/>      samesite               = optional(string)<br/>      secure                 = optional(string)<br/>      zero_downtime_failover = optional(string)<br/>    }))<br/><br/>    # BETA in the Cloudflare API and not generally available. Rules are ordered<br/>    # by priority, so they are taken as a map and sorted by key for stability.<br/>    rules = optional(map(object({<br/>      name       = optional(string)<br/>      condition  = optional(string)<br/>      disabled   = optional(bool)<br/>      priority   = optional(number)<br/>      terminates = optional(bool)<br/><br/>      fixed_response = optional(object({<br/>        content_type = optional(string)<br/>        location     = optional(string)<br/>        message_body = optional(string)<br/>        status_code  = optional(number)<br/>      }))<br/><br/>      overrides = optional(object({<br/>        default_pools        = optional(list(string))<br/>        fallback_pool        = optional(string)<br/>        region_pools         = optional(map(list(string)))<br/>        country_pools        = optional(map(list(string)))<br/>        pop_pools            = optional(map(list(string)))<br/>        steering_policy      = optional(string)<br/>        session_affinity     = optional(string)<br/>        session_affinity_ttl = optional(number)<br/>        ttl                  = optional(number)<br/><br/>        adaptive_routing = optional(object({<br/>          failover_across_pools = optional(bool)<br/>        }))<br/>        location_strategy = optional(object({<br/>          mode       = optional(string)<br/>          prefer_ecs = optional(string)<br/>        }))<br/>        random_steering = optional(object({<br/>          default_weight = optional(number)<br/>          pool_weights   = optional(map(number))<br/>        }))<br/>        session_affinity_attributes = optional(object({<br/>          drain_duration         = optional(number)<br/>          headers                = optional(list(string))<br/>          require_all_headers    = optional(bool)<br/>          samesite               = optional(string)<br/>          secure                 = optional(string)<br/>          zero_downtime_failover = optional(string)<br/>        }))<br/>      }))<br/>    })), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Cloudflare zone ID that owns the load balancers. Load balancers are zone scoped even though their pools are account scoped. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_enabled"></a> [enabled](#output\_enabled) | Whether this submodule created its resources. |
| <a name="output_hostnames"></a> [hostnames](#output\_hostnames) | Resolved load balancer hostnames, keyed by the keys of var.load\_balancers. |
| <a name="output_load_balancer_ids"></a> [load\_balancer\_ids](#output\_load\_balancer\_ids) | Load balancer IDs, keyed by the keys of var.load\_balancers. |
| <a name="output_load_balancers"></a> [load\_balancers](#output\_load\_balancers) | Full cloudflare\_load\_balancer objects, keyed by the keys of var.load\_balancers. |
<!-- END_TF_DOCS -->
