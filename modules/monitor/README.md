# Submodule: monitor

Health checking.

Creates load balancer monitors, monitor groups, and the standalone zone level Health Checks product.

| Resource | Scope | Purpose |
|----------|-------|---------|
| `cloudflare_load_balancer_monitor` | account | How Cloudflare probes the origins of any pool that references it |
| `cloudflare_load_balancer_monitor_group` | account | Bundles several monitors so a pool is judged from more than one probe |
| `cloudflare_healthcheck` | zone | Standalone health check, independent of load balancing |

Monitor group members reference a monitor either by `monitor_key`, naming a key in `var.monitors`, or by
`monitor_id` for a monitor managed elsewhere. Exactly one of the two.

Members and monitors are maps, not lists, so adding or removing one does not shift the rest. The list handed to
the provider is sorted by key, which keeps plans clean.

## Usage

```hcl
module "monitor" {
  source  = "terraform-cf-modules/network/cloudflare//modules/monitor"
  version = "~> 0.1"

  enabled = true
  account_id = var.account_id
  zone_id    = var.zone_id

  monitors = {
    http = {
      type           = "http"
      path           = "/healthz"
      expected_codes = "2xx"
      interval       = 60
    }
    tcp = {
      type = "tcp"
      port = 8080
    }
  }

  monitor_groups = {
    combined = {
      description = "HTTP and TCP judged together"

      members = {
        http = { monitor_key = "http" }
        tcp  = { monitor_key = "tcp", monitoring_only = true }
      }
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Cloudflare account ID that owns the load balancer monitors and monitor groups. | `string` | `null` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Whether to create the resources managed by this submodule. | `bool` | `true` | no |
| <a name="input_healthchecks"></a> [healthchecks](#input\_healthchecks) | Standalone zone level health checks to create, keyed by a stable identifier. These are the Cloudflare<br/>Health Checks product, independent of load balancing, and require var.zone\_id. | <pre>map(object({<br/>    address               = string<br/>    name                  = optional(string)<br/>    type                  = optional(string, "HTTP")<br/>    description           = optional(string)<br/>    check_regions         = optional(list(string))<br/>    consecutive_fails     = optional(number)<br/>    consecutive_successes = optional(number)<br/>    interval              = optional(number)<br/>    retries               = optional(number)<br/>    timeout               = optional(number)<br/>    suspended             = optional(bool)<br/>    http_config = optional(object({<br/>      allow_insecure   = optional(bool)<br/>      expected_body    = optional(string)<br/>      expected_codes   = optional(list(string))<br/>      follow_redirects = optional(bool)<br/>      header           = optional(map(list(string)))<br/>      method           = optional(string)<br/>      path             = optional(string)<br/>      port             = optional(number)<br/>    }))<br/>    tcp_config = optional(object({<br/>      method = optional(string)<br/>      port   = optional(number)<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_monitor_groups"></a> [monitor\_groups](#input\_monitor\_groups) | Load balancer monitor groups to create, keyed by a stable identifier. A monitor group bundles several monitors<br/>so a pool can be judged healthy or unhealthy from more than one probe. Each member either names a key in<br/>var.monitors through monitor\_key, or supplies an existing monitor ID through monitor\_id. | <pre>map(object({<br/>    description = string<br/>    members = map(object({<br/>      monitor_key     = optional(string)<br/>      monitor_id      = optional(string)<br/>      enabled         = optional(bool, true)<br/>      monitoring_only = optional(bool, false)<br/>      must_be_healthy = optional(bool, true)<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_monitors"></a> [monitors](#input\_monitors) | Load balancer monitors to create, keyed by a stable identifier. A monitor defines how Cloudflare probes the<br/>origins of any pool that references it. Account scoped, so var.account\_id is required when this map is non empty. | <pre>map(object({<br/>    type             = optional(string, "http")<br/>    description      = optional(string)<br/>    method           = optional(string)<br/>    path             = optional(string)<br/>    port             = optional(number)<br/>    interval         = optional(number)<br/>    timeout          = optional(number)<br/>    retries          = optional(number)<br/>    consecutive_up   = optional(number)<br/>    consecutive_down = optional(number)<br/>    expected_body    = optional(string)<br/>    expected_codes   = optional(string)<br/>    follow_redirects = optional(bool)<br/>    allow_insecure   = optional(bool)<br/>    probe_zone       = optional(string)<br/>    header           = optional(map(list(string)))<br/>  }))</pre> | `{}` | no |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Cloudflare zone ID that owns the standalone health checks. Only needed when var.healthchecks is non empty. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_enabled"></a> [enabled](#output\_enabled) | Whether this submodule created its resources. |
| <a name="output_healthcheck_ids"></a> [healthcheck\_ids](#output\_healthcheck\_ids) | Health check IDs, keyed by the keys of var.healthchecks. |
| <a name="output_healthchecks"></a> [healthchecks](#output\_healthchecks) | Full cloudflare\_healthcheck objects, keyed by the keys of var.healthchecks. |
| <a name="output_monitor_group_ids"></a> [monitor\_group\_ids](#output\_monitor\_group\_ids) | Monitor group IDs, keyed by the keys of var.monitor\_groups. |
| <a name="output_monitor_groups"></a> [monitor\_groups](#output\_monitor\_groups) | Full cloudflare\_load\_balancer\_monitor\_group objects, keyed by the keys of var.monitor\_groups. |
| <a name="output_monitor_ids"></a> [monitor\_ids](#output\_monitor\_ids) | Monitor IDs, keyed by the keys of var.monitors. Feed these into a pool's monitor input. |
| <a name="output_monitors"></a> [monitors](#output\_monitors) | Full cloudflare\_load\_balancer\_monitor objects, keyed by the keys of var.monitors. |
<!-- END_TF_DOCS -->
