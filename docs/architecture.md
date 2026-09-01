# Architecture

This module covers Cloudflare's network layer: load balancing, health checking, Spectrum, the Magic products, and
IP addressing.

The root module builds the piece people actually reach for, a working load balancer. It creates monitors, then
the pools that reference them, then the load balancers that steer across those pools, resolving map keys to
Cloudflare IDs along the way. Everything else is a standalone building block under `modules/`.

## Resource map

| Terraform resource | Cloudflare object | Created by |
|--------------------|-------------------|------------|
| `cloudflare_load_balancer_monitor` | Load balancer monitor | root / `modules/monitor` |
| `cloudflare_load_balancer_monitor_group` | Load balancer monitor group | root / `modules/monitor` |
| `cloudflare_healthcheck` | Standalone health check | root / `modules/monitor` |
| `cloudflare_load_balancer_pool` | Load balancer pool | root / `modules/pool` |
| `cloudflare_load_balancer` | Load balancer | root / `modules/load-balancer` |
| `cloudflare_spectrum_application` | Spectrum application | `modules/spectrum` |
| `cloudflare_magic_wan_gre_tunnel` | Magic WAN GRE tunnel | `modules/magic-wan` |
| `cloudflare_magic_wan_ipsec_tunnel` | Magic WAN IPsec tunnel | `modules/magic-wan` |
| `cloudflare_magic_wan_static_route` | Magic WAN static route | `modules/magic-wan` |
| `cloudflare_magic_transit_connector` | Magic Connector | `modules/magic-transit` |
| `cloudflare_magic_transit_site` | Magic Transit site | `modules/magic-transit` |
| `cloudflare_magic_transit_site_lan` | Site LAN interface | `modules/magic-transit` |
| `cloudflare_magic_transit_site_wan` | Site WAN interface | `modules/magic-transit` |
| `cloudflare_magic_transit_site_acl` | Site ACL policy | `modules/magic-transit` |
| `cloudflare_byo_ip_prefix` | BYOIP prefix | `modules/addressing` |
| `cloudflare_address_map` | Address map | `modules/addressing` |
| `cloudflare_magic_network_monitoring_configuration` | MNM configuration | `modules/monitoring` |
| `cloudflare_magic_network_monitoring_rule` | MNM rule | `modules/monitoring` |

## Scope

The module is anchored by both `account_id` and `zone_id`, and which one you need depends on what you create.

| Input | Required for |
|-------|--------------|
| `account_id` | monitors, monitor groups, pools, Magic WAN, Magic Transit, addressing, network monitoring |
| `zone_id` | load balancers, standalone health checks, Spectrum applications |

The split matters. A pool lives at the account level, so one pool can back load balancers in several zones. Only
the load balancer itself, the hostname that answers DNS queries, is tied to a zone.

## How the load balancing stack fits together

```
monitor  ──probes──▶  origins inside a pool
                          │
                     pool │ (account scoped, reusable across zones)
                          ▼
                  load balancer  (zone scoped hostname)
                          │
              steering_policy decides which pool map applies
```

Callers name monitors and pools by their map key rather than by an ID that does not exist until apply. The root
module translates a key to the created ID and passes anything else through untouched, so a field may hold either
a key from this module or a literal Cloudflare ID for an object managed elsewhere:

```hcl
pools = {
  primary = {
    monitor = "http" # a key in var.monitors, resolved to that monitor's ID
    origins = { a = { address = "192.0.2.10" } }
  }
}

load_balancers = {
  "www.example.com" = {
    default_pools = ["primary", "22222222222222222222222222222222"] # key, then literal ID
    fallback_pool = "primary"
  }
}
```

That resolution covers `default_pools`, `fallback_pool`, `region_pools`, `country_pools`, `pop_pools`, and the
same fields inside a rule's `overrides`.

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

Setting `geo` without populating any of the three geo maps sends every request to `default_pools`, which is
almost never what was intended, so the module rejects that combination.

## Ordering and dependencies

Every dependency in this module is expressed as a reference, so Terraform derives the graph on its own and there
is no `depends_on` anywhere:

- Pools consume monitor IDs, so monitors are created first.
- Load balancers consume pool IDs, so pools are created before them.
- Inside `modules/magic-transit`, a site consumes a connector ID, a LAN or WAN consumes a site ID, and an ACL
  consumes two LAN IDs.

Things Terraform cannot see, and that are on you:

- A BYOIP prefix is registered by Terraform, but Cloudflare approves ownership out of band. `approved` stays at
  `P` (pending) until it does.
- Magic Connector hardware has to be racked and reachable before the site converges.
- A load balancer's `name` must be a hostname inside the zone named by `zone_id`. Cloudflare rejects anything
  else, and Terraform cannot check it for you.

## Known provider quirks

**`origin_port` on Spectrum is a dynamic type.** The provider accepts an integer for a single port and a string
for a range. A Terraform object type constraint unifies every element of a map to one type, so a single map input
cannot carry both forms: passing `1000` and `"1000-2000"` in the same map silently converts the integer to the
string `"1000"`. `modules/spectrum` therefore takes them as two fields, `origin_port` and `origin_port_range`,
and splits the applications across two resource blocks internally. The outputs merge them back, so it is
invisible to callers.

**Nested structures are attributes, not blocks.** Cloudflare regenerated the provider from its OpenAPI spec in
v5.0.0, and things like `session_affinity_attributes`, `origin_steering`, `http_config` and `health_check` are
now typed attributes. Write `origin_steering = { policy = "random" }`, not `origin_steering { ... }`. A `dynamic`
block will not work on any of them.

**`origins`, `rules` and `members` are lists on the wire.** This module takes each of them as a map keyed by a
stable identifier and sorts by key before handing the list to the provider, so adding or removing one entry does
not reorder the rest and generate a spurious diff. For load balancer rules, `priority` is what decides evaluation
order at the edge; the key only decides plan stability.

**`try()` on a value containing unknowns returns a wholly unknown value.** Guarding module outputs with
`try(module.x.y, {})` makes them unknown at plan time, which stops `terraform test` asserting on them and hides
useful information from `terraform plan` output. The submodules here return empty maps when disabled, so the
guard buys nothing and the root outputs do without it.

**`health_sources` on a pool accepts only `null` or exactly `["regional", "global"]`.** Any other combination is
rejected by the API, and setting it requires at least one entry in `check_regions`. Both are validated here so
the failure arrives at plan rather than at apply.

**`cloudflare_load_balancer.rules` is BETA and not general access.** It is wired up, but Cloudflare may reject it
on an account that has not been opted in.

**IPsec pre shared keys cannot live in the tunnel map.** Marking a variable `sensitive` makes it unusable as a
`for_each` argument, because a sensitive value could leak through a resource instance key. `modules/magic-wan`
keeps the keys in a separate sensitive map, `ipsec_tunnel_psks`, keyed the same way.

**`cloudflare_byo_ip_prefix.advertised` is deprecated.** Terraform emits a deprecation warning whenever the full
prefix object is read, which the `byo_ip_prefixes` output does. Cloudflare points at the BGP Prefixes API
instead, which can advertise several BGP routes inside one IP prefix. The provider has no resource for that yet,
so the warning stands; it does not affect the plan.

**Enterprise gating.** Magic WAN, Magic Transit and Spectrum are not available on ordinary accounts. Every
collection for them defaults to empty, and `examples/complete` keeps them behind variables that default to
`false`, so a passing validation run does not imply the products are available.
