# Submodule: magic-wan

Magic WAN.

Creates Magic WAN GRE tunnels, IPsec tunnels, and static routes.

| Resource | Purpose |
|----------|---------|
| `cloudflare_magic_wan_gre_tunnel` | GRE tunnel to a customer edge device |
| `cloudflare_magic_wan_ipsec_tunnel` | IPsec tunnel to a customer edge device |
| `cloudflare_magic_wan_static_route` | Prefix to next hop routing entry |

**Magic WAN is an enterprise product.** Every collection defaults to empty, so the submodule is inert on accounts
Cloudflare has not onboarded.

`interface_address` is a /31 carrying one address for each end of the tunnel. GRE tunnel names are capped at 15
characters by Cloudflare, with no spaces or special characters.

Pre shared keys live in `var.ipsec_tunnel_psks`, a separate sensitive map keyed the same way as
`var.ipsec_tunnels`. Keeping them out of the main map means that map stays free of sensitive values and can drive
`for_each`. Omit a tunnel from the PSK map and Cloudflare generates a key for it, which is the recommended path,
because anything set there is written to Terraform state.

## Usage

```hcl
module "magic_wan" {
  source  = "terraform-cf-modules/network/cloudflare//modules/magic-wan"
  version = "~> 0.1"

  enabled = true
  account_id = var.account_id

  gre_tunnels = {
    branch-gre = {
      cloudflare_gre_endpoint = "203.0.113.1"
      customer_gre_endpoint   = "198.51.100.1"
      interface_address       = "10.10.10.0/31"
      mtu                     = 1476

      health_check_enabled   = true
      health_check_direction = "bidirectional"
      health_check_rate      = "mid"
    }
  }

  static_routes = {
    branch_lan = {
      prefix   = "10.20.0.0/16"
      nexthop  = "10.10.10.1"
      priority = 100
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | ~> 5.24 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | ~> 5.24 |

## Resources

| Name | Type |
| ---- | ---- |
| [cloudflare_magic_wan_gre_tunnel.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/magic_wan_gre_tunnel) | resource |
| [cloudflare_magic_wan_ipsec_tunnel.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/magic_wan_ipsec_tunnel) | resource |
| [cloudflare_magic_wan_static_route.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/magic_wan_static_route) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Cloudflare account ID that owns the Magic WAN tunnels and routes. | `string` | `null` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Whether to create the resources managed by this submodule. | `bool` | `true` | no |
| <a name="input_gre_tunnels"></a> [gre\_tunnels](#input\_gre\_tunnels) | Magic WAN GRE tunnels, keyed by a stable identifier. The map key becomes the tunnel name unless the object<br/>sets name explicitly. Cloudflare caps tunnel names at 15 characters with no spaces or special characters.<br/>interface\_address is a /31 carrying one address for each end of the tunnel.<br/><br/>Magic WAN is an enterprise product. Leave this map empty unless your account is onboarded. | <pre>map(object({<br/>    name                      = optional(string)<br/>    cloudflare_gre_endpoint   = string<br/>    customer_gre_endpoint     = string<br/>    interface_address         = string<br/>    interface_address6        = optional(string)<br/>    description               = optional(string)<br/>    mtu                       = optional(number)<br/>    ttl                       = optional(number)<br/>    automatic_return_routing  = optional(bool)<br/>    health_check_enabled      = optional(bool)<br/>    health_check_direction    = optional(string)<br/>    health_check_rate         = optional(string)<br/>    health_check_type         = optional(string)<br/>    health_check_target_saved = optional(string)<br/>    bgp = optional(object({<br/>      customer_asn   = number<br/>      extra_prefixes = optional(list(string))<br/>      md5_key        = optional(string)<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_ipsec_tunnel_psks"></a> [ipsec\_tunnel\_psks](#input\_ipsec\_tunnel\_psks) | Pre shared keys for IPsec tunnels, keyed by the same identifiers as var.ipsec\_tunnels. Omit a key and<br/>Cloudflare generates one for that tunnel. Anything set here is written to Terraform state, so source it from a<br/>secret manager rather than from a literal in version control. Kept separate from var.ipsec\_tunnels so that<br/>map stays free of sensitive values and can drive for\_each. | `map(string)` | `{}` | no |
| <a name="input_ipsec_tunnels"></a> [ipsec\_tunnels](#input\_ipsec\_tunnels) | Magic WAN IPsec tunnels, keyed by a stable identifier. The map key becomes the tunnel name unless the object<br/>sets name explicitly.<br/><br/>The pre shared key lives in the separate var.ipsec\_tunnel\_psks map, not here, so that this map stays free of<br/>sensitive values and can drive for\_each. Leaving a tunnel out of that map lets Cloudflare generate the key,<br/>which is the recommended path.<br/><br/>Magic WAN is an enterprise product. Leave this map empty unless your account is onboarded. | <pre>map(object({<br/>    name                      = optional(string)<br/>    cloudflare_endpoint       = string<br/>    customer_endpoint         = optional(string)<br/>    interface_address         = string<br/>    interface_address6        = optional(string)<br/>    description               = optional(string)<br/>    replay_protection         = optional(bool)<br/>    automatic_return_routing  = optional(bool)<br/>    custom_remote_fqdn_id     = optional(string)<br/>    health_check_enabled      = optional(bool)<br/>    health_check_direction    = optional(string)<br/>    health_check_rate         = optional(string)<br/>    health_check_type         = optional(string)<br/>    health_check_target_saved = optional(string)<br/>    bgp = optional(object({<br/>      customer_asn   = number<br/>      extra_prefixes = optional(list(string))<br/>      md5_key        = optional(string)<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_static_routes"></a> [static\_routes](#input\_static\_routes) | Magic WAN static routes, keyed by a stable identifier. Each route sends a prefix to a next hop, which is<br/>normally the Cloudflare side address of a GRE or IPsec tunnel. Lower priority values win. | <pre>map(object({<br/>    prefix      = string<br/>    nexthop     = string<br/>    priority    = number<br/>    description = optional(string)<br/>    weight      = optional(number)<br/>    scope = optional(object({<br/>      colo_names   = optional(list(string))<br/>      colo_regions = optional(list(string))<br/>    }))<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_enabled"></a> [enabled](#output\_enabled) | Whether this submodule created its resources. |
| <a name="output_gre_tunnel_ids"></a> [gre\_tunnel\_ids](#output\_gre\_tunnel\_ids) | GRE tunnel IDs, keyed by the keys of var.gre\_tunnels. |
| <a name="output_gre_tunnels"></a> [gre\_tunnels](#output\_gre\_tunnels) | Full cloudflare\_magic\_wan\_gre\_tunnel objects, keyed by the keys of var.gre\_tunnels. |
| <a name="output_ipsec_tunnel_ids"></a> [ipsec\_tunnel\_ids](#output\_ipsec\_tunnel\_ids) | IPsec tunnel IDs, keyed by the keys of var.ipsec\_tunnels. |
| <a name="output_ipsec_tunnels"></a> [ipsec\_tunnels](#output\_ipsec\_tunnels) | Full cloudflare\_magic\_wan\_ipsec\_tunnel objects, keyed by the keys of var.ipsec\_tunnels. Marked sensitive because the object carries the pre shared key. |
| <a name="output_static_route_ids"></a> [static\_route\_ids](#output\_static\_route\_ids) | Static route IDs, keyed by the keys of var.static\_routes. |
| <a name="output_static_routes"></a> [static\_routes](#output\_static\_routes) | Full cloudflare\_magic\_wan\_static\_route objects, keyed by the keys of var.static\_routes. |
<!-- END_TF_DOCS -->
