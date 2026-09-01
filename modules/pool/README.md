# Submodule: pool

Origin pools.

Creates `cloudflare_load_balancer_pool`: a named group of origins that a load balancer can steer traffic to.

Pools are **account scoped** even though the load balancer that consumes them is zone scoped, so one pool can
back load balancers in several zones.

`origins` is a map rather than a list so that adding or removing an origin does not reorder the others. Set
`host_header` on an origin to override the `Host` header Cloudflare sends upstream.

`monitor` and `monitor_group` take Cloudflare IDs. If you want to reference a monitor by key instead, use the
root module, which resolves keys to IDs for you.

## Usage

```hcl
module "pool" {
  source  = "terraform-cf-modules/network/cloudflare//modules/pool"
  version = "~> 0.1"

  enabled = true
  account_id = var.account_id

  pools = {
    europe = {
      description     = "European origins"
      monitor         = module.monitor.monitor_ids["http"]
      minimum_origins = 1
      check_regions   = ["WEU", "EEU"]
      latitude        = 52.37
      longitude       = 4.89

      origins = {
        ams_1 = { address = "192.0.2.10", port = 443, weight = 0.6, host_header = "example.com" }
        ams_2 = { address = "192.0.2.11", port = 443, weight = 0.4 }
      }

      origin_steering = { policy = "least_outstanding_requests" }
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | ~> 5.24 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | ~> 5.24 |

## Resources

| Name | Type |
| ---- | ---- |
| [cloudflare_load_balancer_pool.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/load_balancer_pool) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Cloudflare account ID that owns the pools. Load balancer pools are always account scoped. | `string` | `null` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Whether to create the resources managed by this submodule. | `bool` | `true` | no |
| <a name="input_pools"></a> [pools](#input\_pools) | Load balancer pools to create, keyed by a stable identifier. The map key becomes the pool name unless the<br/>object sets name explicitly, so keys must be alphanumeric with hyphens or underscores. Each pool holds one or<br/>more origins and optionally references a monitor or monitor group that decides origin health. | <pre>map(object({<br/>    name        = optional(string)<br/>    description = optional(string)<br/>    enabled     = optional(bool, true)<br/><br/>    origins = map(object({<br/>      address            = string<br/>      name               = optional(string)<br/>      enabled            = optional(bool, true)<br/>      port               = optional(number)<br/>      weight             = optional(number)<br/>      flatten_cname      = optional(bool)<br/>      virtual_network_id = optional(string)<br/>      host_header        = optional(string)<br/>    }))<br/><br/>    monitor            = optional(string)<br/>    monitor_group      = optional(string)<br/>    minimum_origins    = optional(number)<br/>    check_regions      = optional(list(string))<br/>    health_sources     = optional(list(string))<br/>    latitude           = optional(number)<br/>    longitude          = optional(number)<br/>    notification_email = optional(string)<br/><br/>    origin_steering = optional(object({<br/>      policy = optional(string)<br/>    }))<br/><br/>    load_shedding = optional(object({<br/>      default_percent = optional(number)<br/>      default_policy  = optional(string)<br/>      session_percent = optional(number)<br/>      session_policy  = optional(string)<br/>    }))<br/><br/>    notification_filter = optional(object({<br/>      origin = optional(object({<br/>        disable = optional(bool)<br/>        healthy = optional(bool)<br/>      }))<br/>      pool = optional(object({<br/>        disable = optional(bool)<br/>        healthy = optional(bool)<br/>      }))<br/>    }))<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_enabled"></a> [enabled](#output\_enabled) | Whether this submodule created its resources. |
| <a name="output_pool_ids"></a> [pool\_ids](#output\_pool\_ids) | Pool IDs, keyed by the keys of var.pools. Feed these into a load balancer's default\_pools or fallback\_pool. |
| <a name="output_pool_names"></a> [pool\_names](#output\_pool\_names) | Resolved pool names, keyed by the keys of var.pools. |
| <a name="output_pools"></a> [pools](#output\_pools) | Full cloudflare\_load\_balancer\_pool objects, keyed by the keys of var.pools. |
<!-- END_TF_DOCS -->
