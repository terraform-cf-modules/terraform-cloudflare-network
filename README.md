<p align="center">
  <img width="1000" alt="CloudDrove Banner" src="https://clouddrove.s3.ca-central-1.amazonaws.com/img/clouddrove-github-cover.png" />
</p>

<h1 align="center">Terraform Cloudflare Network</h1>
<p align="center"><em>Load balancing, health monitors, Spectrum applications, Magic WAN, and Magic Transit.</em></p>

<p align="center">
  <a href="https://www.terraform.io"><img src="https://img.shields.io/badge/terraform-%3E%3D%201.12-844FBA?logo=terraform&logoColor=white" alt="Terraform" /></a>
  <a href="https://opentofu.org"><img src="https://img.shields.io/badge/opentofu-%3E%3D%201.12-FFDA18?logo=opentofu&logoColor=black" alt="OpenTofu" /></a>
  <a href="https://registry.terraform.io/providers/cloudflare/cloudflare/latest"><img src="https://img.shields.io/badge/provider-cloudflare%20~%3E%205.24-F38020?logo=cloudflare&logoColor=white" alt="Cloudflare Provider" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" alt="License" /></a>
</p>

---

Cloudflare's network layer: load balancing, health checking, Spectrum, the Magic products, and IP addressing.

The root module builds a working load balancer. It creates the monitors, then the pools that reference them, then
the load balancers that steer across those pools, resolving map keys to Cloudflare IDs along the way, so you
never hand write an ID that does not exist until apply.

```hcl
module "network" {
  source  = "terraform-cf-modules/network/cloudflare"
  version = "~> 0.1"

  account_id = var.account_id
  zone_id    = var.zone_id

  monitors = {
    http = {
      type           = "http"
      path           = "/healthz"
      expected_codes = "2xx"
      interval       = 60
    }
  }

  pools = {
    primary = {
      monitor = "http" # a key in var.monitors, resolved to that monitor's ID

      origins = {
        origin_a = { address = "192.0.2.10", weight = 1 }
        origin_b = { address = "192.0.2.11", weight = 1 }
      }
    }
  }

  load_balancers = {
    "www.example.com" = {
      default_pools = ["primary"] # a key in var.pools, resolved to that pool's ID
      fallback_pool = "primary"
      proxied       = true
    }
  }
}
```

---

## What it builds

| Submodule | Resources |
|-----------|-----------|
| `monitor` | `cloudflare_load_balancer_monitor`, `cloudflare_load_balancer_monitor_group`, `cloudflare_healthcheck` |
| `pool` | `cloudflare_load_balancer_pool` |
| `load-balancer` | `cloudflare_load_balancer` |
| `spectrum` | `cloudflare_spectrum_application` |
| `magic-wan` | `cloudflare_magic_wan_gre_tunnel`, `cloudflare_magic_wan_ipsec_tunnel`, `cloudflare_magic_wan_static_route` |
| `magic-transit` | `cloudflare_magic_transit_connector`, `cloudflare_magic_transit_site`, `cloudflare_magic_transit_site_lan`, `cloudflare_magic_transit_site_wan`, `cloudflare_magic_transit_site_acl` |
| `addressing` | `cloudflare_byo_ip_prefix`, `cloudflare_address_map` |
| `monitoring` | `cloudflare_magic_network_monitoring_configuration`, `cloudflare_magic_network_monitoring_rule` |

The root module composes `monitor`, `pool` and `load-balancer`. The rest are standalone:

```hcl
module "spectrum" {
  source  = "terraform-cf-modules/network/cloudflare//modules/spectrum"
  version = "~> 0.1"

  zone_id = var.zone_id

  applications = {
    ssh = {
      protocol      = "tcp/22"
      dns           = { type = "CNAME", name = "ssh.example.com" }
      origin_direct = ["tcp://192.0.2.10:22"]
    }
  }
}
```

---

## Scope

| Input | Required for |
|-------|--------------|
| `account_id` | monitors, monitor groups, pools, Magic WAN, Magic Transit, addressing, network monitoring |
| `zone_id` | load balancers, standalone health checks, Spectrum applications |

Pools are account scoped even though the load balancer that consumes them is zone scoped, so one pool can back
load balancers in several zones.

---

## Steering

`steering_policy` on the load balancer decides which pool map is consulted.

| Policy | Pools used |
|--------|-----------|
| `off` (or unset) | `default_pools` in order |
| `geo` | `pop_pools`, then `country_pools`, then `region_pools`, falling back to `default_pools` |
| `random` | any pool, weighted by `random_steering` |
| `dynamic_latency` | closest pool in `default_pools` by round trip time, needs pool health checks |
| `proximity` | closest pool by the pool's own latitude and longitude |
| `least_outstanding_requests` / `least_connections` | pool with the least load, weighted by `random_steering` |

```hcl
load_balancers = {
  "www.example.com" = {
    default_pools   = ["europe", "north_america"]
    fallback_pool   = "north_america"
    proxied         = true
    steering_policy = "geo"

    region_pools  = { WEU = ["europe"], ENAM = ["north_america"] }
    country_pools = { GB = ["europe", "north_america"] }

    adaptive_routing = { failover_across_pools = true }
  }
}
```

---

## Enterprise features

Magic WAN, Magic Transit and Spectrum are not available on ordinary Cloudflare accounts. Every collection for
them defaults to empty, and `examples/complete` keeps them behind variables that default to `false`, so a passing
validation run does not imply the products are available on your account.

---

## Repository layout

```
terraform.tf                provider and version requirements
main.tf                     root module, composes the load balancing stack
variables.tf                root module inputs
outputs.tf                  root module outputs
locals.tf                   key to ID resolution
modules/monitor/            monitors, monitor groups, health checks
modules/pool/               load balancer pools
modules/load-balancer/      load balancers
modules/spectrum/           Spectrum applications
modules/magic-wan/          GRE and IPsec tunnels, static routes
modules/magic-transit/      sites, LANs, WANs, ACLs, connectors
modules/addressing/         BYOIP prefixes and address maps
modules/monitoring/         Magic Network Monitoring
examples/basic/             one monitor, one pool, one load balancer
examples/complete/          every optional feature turned on
examples/multi-zone-pools/  one set of account scoped pools behind several zones
wrappers/                   for_each wrapper for many zones
tests/                      native terraform test files
docs/architecture.md        resource map and provider quirks
```

---

## The rules

Full detail lives in the [organisation contributing guide](https://github.com/terraform-cf-modules/.github/blob/main/CONTRIBUTING.md).
The short version:

- **Product scoped, not resource scoped.** One module maps to a Cloudflare product area. Single resource wrappers
  are not published here.
- **Provider v5 only.** Verify every resource and attribute against the
  [current provider docs](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs). Cloudflare
  renamed most resources in v5.0.0, and older examples (including anything an AI assistant recalls from training
  data) are frequently wrong.
- **`enabled` everywhere**, honoured on every resource.
- **Maps of objects, never lists.** A list reorder destroys and recreates resources. Use `optional()` inside the
  object type and default the map to `{}`.
- **`validation` blocks on every enum.**
- **No `provider` block inside a module.** Authentication belongs to the caller.
- **No credentials as inputs.** Secret outputs are marked `sensitive`.
- **No tagging or labelling convention.** Cloudflare has no general tag surface, so there is deliberately no
  labels module here.

---

## Local development

```bash
pre-commit install

make fmt        # terraform fmt -recursive
make validate   # init and validate every directory
make lint       # tflint
make docs       # regenerate the terraform-docs blocks
make test       # mocked terraform test, no credentials needed
make security   # trivy, checkov, gitleaks
make ci         # all of the above
```

`make test` runs against `mock_provider`, so it needs no Cloudflare credentials. The live tests in
`tests/integration.tftest.hcl` run only on schedule and manual dispatch.

---

## CI

Most workflows call the shared, actively maintained
[clouddrove/github-shared-workflows](https://github.com/clouddrove/github-shared-workflows) at `@v2`, so the
standard changes in one place for every repository.

| Workflow | Source | Purpose |
|----------|--------|---------|
| `tf-checks` | shared | init and validate both examples |
| `tflint` | shared | lint |
| `checkov` | shared | policy scan |
| `gitleaks` | shared | secret scan |
| `pr_checks` | shared | Conventional Commit pull request title |
| `auto_assignee` | shared | reviewer assignment |
| `automerge` | shared | auto merge on green |
| `stale_pr` | shared | stale handling |
| `readme` | shared | rebuild README from README.yaml |
| `tag-release` | shared | tag and changelog on merge |
| `opentofu` | local | OpenTofu compatibility, no shared equivalent yet |
| `test` | local | `terraform test` with mocked provider |
| `integration` | local | live apply against a test account, scheduled only |

### Required organisation secrets

| Secret | Used by |
|--------|---------|
| `GITHUB` | `tflint`, `tag-release`, `auto_assignee`, `automerge`, `readme` |
| `SLACK_WEBHOOK_TERRAFORM` | `readme` |
| `CLOUDFLARE_API_TOKEN` | `integration` |
| `CLOUDFLARE_TEST_ACCOUNT_ID` | `integration` |
| `CLOUDFLARE_TEST_ZONE_ID` | `integration` |
| `CLOUDFLARE_TEST_ZONE_NAME` | `integration`, used to build the load balancer hostname |

---

## Inputs and outputs

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | ~> 5.24 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_load_balancer"></a> [load\_balancer](#module\_load\_balancer) | ./modules/load-balancer | n/a |
| <a name="module_monitor"></a> [monitor](#module\_monitor) | ./modules/monitor | n/a |
| <a name="module_pool"></a> [pool](#module\_pool) | ./modules/pool | n/a |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Cloudflare account ID that owns the resources. Load balancer monitors, monitor groups and pools are account scoped, so this is required whenever var.monitors, var.monitor\_groups or var.pools is non empty. | `string` | `null` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Whether to create the resources managed by this module. Set to false to disable the module without removing the block. | `bool` | `true` | no |
| <a name="input_healthchecks"></a> [healthchecks](#input\_healthchecks) | Standalone zone level health checks to create, keyed by a stable identifier. These are the Cloudflare Health<br/>Checks product, independent of load balancing. The map key becomes the check name unless the object sets name. | <pre>map(object({<br/>    address               = string<br/>    name                  = optional(string)<br/>    type                  = optional(string, "HTTP")<br/>    description           = optional(string)<br/>    check_regions         = optional(list(string))<br/>    consecutive_fails     = optional(number)<br/>    consecutive_successes = optional(number)<br/>    interval              = optional(number)<br/>    retries               = optional(number)<br/>    timeout               = optional(number)<br/>    suspended             = optional(bool)<br/>    http_config = optional(object({<br/>      allow_insecure   = optional(bool)<br/>      expected_body    = optional(string)<br/>      expected_codes   = optional(list(string))<br/>      follow_redirects = optional(bool)<br/>      header           = optional(map(list(string)))<br/>      method           = optional(string)<br/>      path             = optional(string)<br/>      port             = optional(number)<br/>    }))<br/>    tcp_config = optional(object({<br/>      method = optional(string)<br/>      port   = optional(number)<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_load_balancers"></a> [load\_balancers](#input\_load\_balancers) | Load balancers to create, keyed by a stable identifier. The map key becomes the DNS hostname unless the object<br/>sets name explicitly.<br/><br/>Every pool reference (default\_pools, fallback\_pool, region\_pools, country\_pools, pop\_pools and the same fields<br/>inside rule overrides) accepts either a key from var.pools or a literal Cloudflare pool ID. Anything that<br/>matches a key is resolved to the created ID; anything else is passed through unchanged.<br/><br/>steering\_policy decides which of those maps is consulted. Set it to geo to use region\_pools, country\_pools and<br/>pop\_pools; leave it off or unset to use default\_pools alone. | <pre>map(object({<br/>    name          = optional(string)<br/>    default_pools = list(string)<br/>    fallback_pool = string<br/><br/>    description = optional(string)<br/>    enabled     = optional(bool, true)<br/>    proxied     = optional(bool)<br/>    ttl         = optional(number)<br/>    networks    = optional(list(string))<br/><br/>    steering_policy      = optional(string)<br/>    session_affinity     = optional(string)<br/>    session_affinity_ttl = optional(number)<br/><br/>    region_pools  = optional(map(list(string)))<br/>    country_pools = optional(map(list(string)))<br/>    pop_pools     = optional(map(list(string)))<br/><br/>    adaptive_routing = optional(object({<br/>      failover_across_pools = optional(bool)<br/>    }))<br/><br/>    location_strategy = optional(object({<br/>      mode       = optional(string)<br/>      prefer_ecs = optional(string)<br/>    }))<br/><br/>    random_steering = optional(object({<br/>      default_weight = optional(number)<br/>      pool_weights   = optional(map(number))<br/>    }))<br/><br/>    session_affinity_attributes = optional(object({<br/>      drain_duration         = optional(number)<br/>      headers                = optional(list(string))<br/>      require_all_headers    = optional(bool)<br/>      samesite               = optional(string)<br/>      secure                 = optional(string)<br/>      zero_downtime_failover = optional(string)<br/>    }))<br/><br/>    rules = optional(map(object({<br/>      name       = optional(string)<br/>      condition  = optional(string)<br/>      disabled   = optional(bool)<br/>      priority   = optional(number)<br/>      terminates = optional(bool)<br/><br/>      fixed_response = optional(object({<br/>        content_type = optional(string)<br/>        location     = optional(string)<br/>        message_body = optional(string)<br/>        status_code  = optional(number)<br/>      }))<br/><br/>      overrides = optional(object({<br/>        default_pools        = optional(list(string))<br/>        fallback_pool        = optional(string)<br/>        region_pools         = optional(map(list(string)))<br/>        country_pools        = optional(map(list(string)))<br/>        pop_pools            = optional(map(list(string)))<br/>        steering_policy      = optional(string)<br/>        session_affinity     = optional(string)<br/>        session_affinity_ttl = optional(number)<br/>        ttl                  = optional(number)<br/><br/>        adaptive_routing = optional(object({<br/>          failover_across_pools = optional(bool)<br/>        }))<br/>        location_strategy = optional(object({<br/>          mode       = optional(string)<br/>          prefer_ecs = optional(string)<br/>        }))<br/>        random_steering = optional(object({<br/>          default_weight = optional(number)<br/>          pool_weights   = optional(map(number))<br/>        }))<br/>        session_affinity_attributes = optional(object({<br/>          drain_duration         = optional(number)<br/>          headers                = optional(list(string))<br/>          require_all_headers    = optional(bool)<br/>          samesite               = optional(string)<br/>          secure                 = optional(string)<br/>          zero_downtime_failover = optional(string)<br/>        }))<br/>      }))<br/>    })), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_monitor_groups"></a> [monitor\_groups](#input\_monitor\_groups) | Load balancer monitor groups to create, keyed by a stable identifier. A monitor group bundles several monitors<br/>so a pool can be judged healthy or unhealthy from more than one probe. Each member either names a key in<br/>var.monitors through monitor\_key, or supplies an existing monitor ID through monitor\_id. | <pre>map(object({<br/>    description = string<br/>    members = map(object({<br/>      monitor_key     = optional(string)<br/>      monitor_id      = optional(string)<br/>      enabled         = optional(bool, true)<br/>      monitoring_only = optional(bool, false)<br/>      must_be_healthy = optional(bool, true)<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_monitors"></a> [monitors](#input\_monitors) | Load balancer monitors to create, keyed by a stable identifier. A monitor defines how Cloudflare probes the<br/>origins of any pool that references it. Reference a monitor from a pool by putting its key in the pool's<br/>monitor field; this module resolves keys to IDs. | <pre>map(object({<br/>    type             = optional(string, "http")<br/>    description      = optional(string)<br/>    method           = optional(string)<br/>    path             = optional(string)<br/>    port             = optional(number)<br/>    interval         = optional(number)<br/>    timeout          = optional(number)<br/>    retries          = optional(number)<br/>    consecutive_up   = optional(number)<br/>    consecutive_down = optional(number)<br/>    expected_body    = optional(string)<br/>    expected_codes   = optional(string)<br/>    follow_redirects = optional(bool)<br/>    allow_insecure   = optional(bool)<br/>    probe_zone       = optional(string)<br/>    header           = optional(map(list(string)))<br/>  }))</pre> | `{}` | no |
| <a name="input_pools"></a> [pools](#input\_pools) | Load balancer pools to create, keyed by a stable identifier. The map key becomes the pool name unless the<br/>object sets name explicitly.<br/><br/>monitor and monitor\_group each accept either a key from var.monitors or var.monitor\_groups, or a literal<br/>Cloudflare ID for something managed elsewhere. Anything that matches a key is resolved to the created ID;<br/>anything else is passed through unchanged. | <pre>map(object({<br/>    name        = optional(string)<br/>    description = optional(string)<br/>    enabled     = optional(bool, true)<br/><br/>    origins = map(object({<br/>      address            = string<br/>      name               = optional(string)<br/>      enabled            = optional(bool, true)<br/>      port               = optional(number)<br/>      weight             = optional(number)<br/>      flatten_cname      = optional(bool)<br/>      virtual_network_id = optional(string)<br/>      host_header        = optional(string)<br/>    }))<br/><br/>    monitor            = optional(string)<br/>    monitor_group      = optional(string)<br/>    minimum_origins    = optional(number)<br/>    check_regions      = optional(list(string))<br/>    health_sources     = optional(list(string))<br/>    latitude           = optional(number)<br/>    longitude          = optional(number)<br/>    notification_email = optional(string)<br/><br/>    origin_steering = optional(object({<br/>      policy = optional(string)<br/>    }))<br/><br/>    load_shedding = optional(object({<br/>      default_percent = optional(number)<br/>      default_policy  = optional(string)<br/>      session_percent = optional(number)<br/>      session_policy  = optional(string)<br/>    }))<br/><br/>    notification_filter = optional(object({<br/>      origin = optional(object({<br/>        disable = optional(bool)<br/>        healthy = optional(bool)<br/>      }))<br/>      pool = optional(object({<br/>        disable = optional(bool)<br/>        healthy = optional(bool)<br/>      }))<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Cloudflare zone ID that owns the resources. Load balancers and standalone health checks are zone scoped, so this is required whenever var.load\_balancers or var.healthchecks is non empty. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_enabled"></a> [enabled](#output\_enabled) | Whether this module created its resources. |
| <a name="output_healthcheck_ids"></a> [healthcheck\_ids](#output\_healthcheck\_ids) | Health check IDs, keyed by the keys of var.healthchecks. |
| <a name="output_healthchecks"></a> [healthchecks](#output\_healthchecks) | Full cloudflare\_healthcheck objects, keyed by the keys of var.healthchecks. |
| <a name="output_hostnames"></a> [hostnames](#output\_hostnames) | Resolved load balancer hostnames, keyed by the keys of var.load\_balancers. |
| <a name="output_load_balancer_ids"></a> [load\_balancer\_ids](#output\_load\_balancer\_ids) | Load balancer IDs, keyed by the keys of var.load\_balancers. |
| <a name="output_load_balancers"></a> [load\_balancers](#output\_load\_balancers) | Full cloudflare\_load\_balancer objects, keyed by the keys of var.load\_balancers. |
| <a name="output_monitor_group_ids"></a> [monitor\_group\_ids](#output\_monitor\_group\_ids) | Monitor group IDs, keyed by the keys of var.monitor\_groups. |
| <a name="output_monitor_groups"></a> [monitor\_groups](#output\_monitor\_groups) | Full cloudflare\_load\_balancer\_monitor\_group objects, keyed by the keys of var.monitor\_groups. |
| <a name="output_monitor_ids"></a> [monitor\_ids](#output\_monitor\_ids) | Monitor IDs, keyed by the keys of var.monitors. |
| <a name="output_monitors"></a> [monitors](#output\_monitors) | Full cloudflare\_load\_balancer\_monitor objects, keyed by the keys of var.monitors. |
| <a name="output_pool_ids"></a> [pool\_ids](#output\_pool\_ids) | Pool IDs, keyed by the keys of var.pools. |
| <a name="output_pools"></a> [pools](#output\_pools) | Full cloudflare\_load\_balancer\_pool objects, keyed by the keys of var.pools. |
<!-- END_TF_DOCS -->

---

## License

Apache 2.0. See [LICENSE](LICENSE).

Maintained by [CloudDrove](https://clouddrove.com) and [Cloud Wizz](https://github.com/cloud-wizz).
