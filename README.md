<!-- This file was automatically generated from `README.yaml`. Make all changes to `README.yaml` and run `make readme` to rebuild this file. -->
<p align="center">
  <img width="1024" height="250" alt="CloudDrove" src="https://clouddrove.s3.ca-central-1.amazonaws.com/Logo/banner.png" />
</p>
<h1 align="center">
    Terraform Cloudflare Network
</h1>

<p align="center" style="font-size: 1.2rem;">
    With our comprehensive DevOps toolkit, streamline operations, automate workflows, enhance collaboration and deploy with confidence.
</p>

<p align="center">

<a href="https://www.terraform.io">
  <img src="https://img.shields.io/badge/Terraform-v1.12.0-green" alt="Terraform">
</a>
<a href="LICENSE">
  <img src="https://img.shields.io/badge/License-APACHE-blue.svg" alt="Licence">
</a>
<a href="CHANGELOG.md">
  <img src="https://img.shields.io/badge/Changelog-blue" alt="Changelog">
</a>
<a href="https://github.com/terraform-cf-modules/terraform-cloudflare-network/actions/workflows/tf-checks.yml">
  <img src="https://github.com/terraform-cf-modules/terraform-cloudflare-network/actions/workflows/tf-checks.yml/badge.svg" alt="tf-checks">
</a>
<a href="https://github.com/terraform-cf-modules/terraform-cloudflare-network/actions/workflows/tflint.yml">
  <img src="https://github.com/terraform-cf-modules/terraform-cloudflare-network/actions/workflows/tflint.yml/badge.svg" alt="tf-lint">
</a>
<a href="https://github.com/terraform-cf-modules/terraform-cloudflare-network/actions/workflows/checkov.yml">
  <img src="https://github.com/terraform-cf-modules/terraform-cloudflare-network/actions/workflows/checkov.yml/badge.svg" alt="checkov">
</a>
<a href="https://github.com/terraform-cf-modules/terraform-cloudflare-network/actions/workflows/test.yml">
  <img src="https://github.com/terraform-cf-modules/terraform-cloudflare-network/actions/workflows/test.yml/badge.svg" alt="test">
</a>

</p>
<hr>


Cloudflare's network layer: load balancing, health checking, Spectrum, the Magic products, and IP addressing.

The root module builds a working load balancer out of three pieces, created in the order Cloudflare needs them.
Monitors define how origins are probed. Pools reference a monitor and hold the origins. Load balancers steer
traffic across those pools. That monitor to pool to load balancer wiring is what the root module is for, and
every reference along the chain accepts either a map key from this module or a literal Cloudflare ID. A pool
can say `monitor = "http"` to point at a key in `var.monitors`, or it can carry the ID of a monitor some other
configuration owns. Anything that matches a key is resolved to the created ID, anything else is passed through
unchanged, so you never hand write an ID that does not exist until apply. The same rule applies to
`default_pools`, `fallback_pool`, `region_pools`, `country_pools`, `pop_pools` and the pool references inside
rule overrides.

Account scope and zone scope are not the same thing here, which is why both IDs are separate inputs.

| Input | Required for |
|-------|--------------|
| `account_id` | monitors, monitor groups, pools, Magic WAN, Magic Transit, addressing, network monitoring |
| `zone_id` | load balancers, standalone health checks, Spectrum applications |

Pools are account scoped even though the load balancer that consumes them is zone scoped, so one set of pools
can back load balancers in several zones. `examples/multi-zone-pools` shows that arrangement, and `wrappers/`
applies the whole stack once per zone.

`steering_policy` on a load balancer decides which pool map is actually consulted, which is the setting people
most often get wrong.

| Policy | Pools used |
|--------|-----------|
| `off` (or unset) | `default_pools` in order |
| `geo` | `pop_pools`, then `country_pools`, then `region_pools`, falling back to `default_pools` |
| `random` | any pool, weighted by `random_steering` |
| `dynamic_latency` | closest pool in `default_pools` by round trip time, needs pool health checks |
| `proximity` | closest pool by the pool's own latitude and longitude |
| `least_outstanding_requests` / `least_connections` | pool with the least load, weighted by `random_steering` |

Magic WAN and Magic Transit are enterprise products that Cloudflare has to onboard an account for, and Spectrum
needs a paid plan. Every collection for them defaults to empty, so they are off unless you ask for them, and
`examples/complete` keeps them behind variables that default to `false`. A passing plan therefore does not
imply the products are available on your account. This module targets Cloudflare provider v5, which renamed
most resources in v5.0.0, so check resource names against the current provider documentation rather than older
examples. See [docs/architecture.md](docs/architecture.md) for the full resource map and the provider quirks.


## Prerequisites and Providers

This table contains both Prerequisites and Providers:

| Description | Name | Version |
|-------------|------|---------|
| Prerequisite | Terraform | >= 1.12.0 |
| Prerequisite | OpenTofu | >= 1.12.0 |
| Provider | cloudflare | ~> 5.24 |

---


## 🧩 Submodules

Each submodule is separately addressable with the double slash source syntax, so you can take only the piece you need instead of the whole root module.

| Submodule | Source | Description |
|-----------|--------|-------------|
| `monitor` | `terraform-cf-modules/network/cloudflare//modules/monitor` | Health checking: account scoped load balancer monitors and monitor groups, plus the standalone zone level Health Checks product. |
| `pool` | `terraform-cf-modules/network/cloudflare//modules/pool` | Origin pools, a named group of origins a load balancer can steer to. Account scoped, so one pool can back load balancers in several zones. |
| `load-balancer` | `terraform-cf-modules/network/cloudflare//modules/load-balancer` | Zone scoped load balancer hostnames with their steering policy, session affinity and rules. Pool references here are literal IDs; use the root module to reference pools by key. |
| `spectrum` | `terraform-cf-modules/network/cloudflare//modules/spectrum` | Spectrum applications, proxying arbitrary TCP and UDP traffic rather than just HTTP. Paid plans only. |
| `magic-wan` | `terraform-cf-modules/network/cloudflare//modules/magic-wan` | Magic WAN GRE tunnels, IPsec tunnels with their pre shared keys, and static routes. Enterprise only, empty by default. |
| `magic-transit` | `terraform-cf-modules/network/cloudflare//modules/magic-transit` | Magic Transit site topology: connectors, sites, and the LAN, WAN and ACL objects that hang off a site. Enterprise only, empty by default. |
| `addressing` | `terraform-cf-modules/network/cloudflare//modules/addressing` | Bring your own IP prefixes and address maps. |
| `monitoring` | `terraform-cf-modules/network/cloudflare//modules/monitoring` | Magic Network Monitoring configuration and its alert rules. |

The root module composes `monitor`, `pool` and `load-balancer`. The other five are standalone, because nothing
else in the product area needs to be wired to them.

---


## 🚀 Usage

### A working load balancer

The pool references the monitor by its map key, and the load balancer references the pool by its map key. The
module resolves both to Cloudflare IDs.

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

### Geo steering across two regions

`steering_policy = "geo"` makes `region_pools` and `country_pools` the pools that matter, with `default_pools`
as the fallback for anywhere not listed.

```hcl
module "network" {
  source  = "terraform-cf-modules/network/cloudflare"
  version = "~> 0.1"

  account_id = var.account_id
  zone_id    = var.zone_id

  monitors = {
    http = { type = "http", path = "/healthz" }
  }

  pools = {
    europe = {
      monitor   = "http"
      latitude  = 52.37
      longitude = 4.89
      origins   = { ams = { address = "192.0.2.10" } }
    }

    north_america = {
      monitor   = "http"
      latitude  = 37.77
      longitude = -122.42
      origins   = { sfo = { address = "192.0.2.20" } }
    }
  }

  load_balancers = {
    "www.example.com" = {
      default_pools   = ["europe", "north_america"]
      fallback_pool   = "north_america"
      proxied         = true
      steering_policy = "geo"

      region_pools = {
        WEU  = ["europe"]
        ENAM = ["north_america"]
      }

      country_pools = {
        GB = ["europe", "north_america"]
      }

      adaptive_routing = {
        failover_across_pools = true
      }
    }
  }
}
```

### A submodule on its own

Spectrum has nothing to do with load balancing, so it is used directly. `protocol` is a port specification at
Cloudflare's edge, and traffic goes to either `origin_direct` or `origin_dns` plus an origin port.

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


## 📦 Examples

> ⚠️ **Important:** Avoid using the `main` branch directly, as it may include unstable changes. Always use stable [release versions](https://github.com/terraform-cf-modules/terraform-cloudflare-network/releases).

Explore real-world usage scenarios and implementation patterns in the [`examples/`](./examples/) directory.

---


## 📥 Inputs and Outputs

Detailed input variables and output values are documented for easier integration and day-to-day usage.

📘 [View full documentation](docs/io.md)

---


## 📝 Changelog

Track module updates, improvements, and breaking changes across versions.

📌 [View Changelog](CHANGELOG.md)

---


## ✨ Contributors

Big thanks to our contributors for elevating our project with their dedication and expertise!

<div align="center">
  <a href="https://github.com/terraform-cf-modules/terraform-cloudflare-network/graphs/contributors" title="Contributors">
    <img src="https://contrib.rocks/image?repo=terraform-cf-modules/terraform-cloudflare-network" />
  </a>
</div>

All contributors must follow the [Conventional Commits](https://www.conventionalcommits.org) specification for commit messages.

---


## 🚀 Our Accomplishment

We maintain Terraform modules across AWS, Azure, Google Cloud, DigitalOcean, Hetzner Cloud and Cloudflare 🙌.

- [**Terraform Module Registry**](https://registry.terraform.io/namespaces/terraform-cf-modules): Discover our Cloudflare modules here.
- [**Full module catalog**](https://github.com/clouddrove/toc): Every CloudDrove module and submodule, across every cloud.

---

## Notes

- Do not use the `main` branch for production deployments.
- Always reference a stable version using Git tags or official releases.
- Using tagged versions ensures consistency, stability, and reproducible deployments.

---

## Feedback

Report issues or request features on [GitHub](https://github.com/terraform-cf-modules/terraform-cloudflare-network/issues), or write to [business@clouddrove.com](mailto:business@clouddrove.com).

## About us

At [CloudDrove](https://clouddrove.com), we build reliable, secure and cost efficient cloud native solutions. Join our [Slack community](https://www.launchpass.com/devops-talks).
