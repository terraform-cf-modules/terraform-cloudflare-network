# Submodule: magic-transit

Magic Transit sites.

Creates the Magic Transit site topology: connectors, sites, and the LAN, WAN, and ACL objects that hang off a
site.

| Resource | Purpose |
|----------|---------|
| `cloudflare_magic_transit_connector` | The appliance that terminates a site |
| `cloudflare_magic_transit_site` | A physical location on the network |
| `cloudflare_magic_transit_site_lan` | LAN side interface, optionally with DHCP relay or a DHCP server |
| `cloudflare_magic_transit_site_wan` | WAN side interface |
| `cloudflare_magic_transit_site_acl` | Allow policy between two LANs on a site |

**Magic Transit is an enterprise product.** Every collection defaults to empty, so the submodule is inert on
accounts Cloudflare has not onboarded.

Objects reference each other by key: a site takes `connector_key`, a LAN or WAN takes `site_key`, and each side
of an ACL takes `lan_key`. Every one of those has an `_id` counterpart for objects managed elsewhere. Terraform
derives the ordering from those references, so no `depends_on` is needed.

## Usage

```hcl
module "magic_transit" {
  source  = "terraform-cf-modules/network/cloudflare//modules/magic-transit"
  version = "~> 0.1"

  enabled = true
  account_id = var.account_id

  connectors = {
    branch = {
      device_serial_number     = "SERIAL0000000000"
      device_provision_license = true
    }
  }

  sites = {
    branch = {
      connector_key = "branch"
      location      = { lat = "51.51", lon = "-0.13" }
    }
  }

  site_lans = {
    branch_lan = {
      site_key = "branch"
      physport = 2
      vlan_tag = 0

      static_addressing = {
        address = "10.20.0.1/24"

        dhcp_server = {
          dhcp_pool_start = "10.20.0.100"
          dhcp_pool_end   = "10.20.0.200"
          dns_servers     = ["1.1.1.1"]
        }
      }
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Cloudflare account ID that owns the Magic Transit sites and connectors. | `string` | `null` | no |
| <a name="input_connectors"></a> [connectors](#input\_connectors) | Magic Connectors to register, keyed by a stable identifier. A connector is the physical or virtual appliance<br/>that terminates a Magic Transit site. Identify the device by serial\_number for hardware you already own, or<br/>set device\_id when Cloudflare has already allocated one.<br/><br/>Magic Transit is an enterprise product. Leave this map empty unless your account is onboarded. | <pre>map(object({<br/>    device_serial_number            = optional(string)<br/>    device_id                       = optional(string)<br/>    device_provision_license        = optional(bool)<br/>    activated                       = optional(bool)<br/>    notes                           = optional(string)<br/>    timezone                        = optional(string)<br/>    interrupt_window_hour_of_day    = optional(number)<br/>    interrupt_window_duration_hours = optional(number)<br/>  }))</pre> | `{}` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Whether to create the resources managed by this submodule. | `bool` | `true` | no |
| <a name="input_site_acls"></a> [site\_acls](#input\_site\_acls) | ACL policies between two LANs on a Magic Transit site, keyed by a stable identifier. The map key becomes the<br/>policy name unless the object sets name explicitly. Each side references a LAN either by lan\_key, naming a key<br/>in var.site\_lans, or by lan\_id. | <pre>map(object({<br/>    site_key = optional(string)<br/>    site_id  = optional(string)<br/><br/>    name        = optional(string)<br/>    description = optional(string)<br/><br/>    lan_1 = object({<br/>      lan_key     = optional(string)<br/>      lan_id      = optional(string)<br/>      lan_name    = optional(string)<br/>      ports       = optional(list(number))<br/>      port_ranges = optional(list(string))<br/>      subnets     = optional(list(string))<br/>    })<br/><br/>    lan_2 = object({<br/>      lan_key     = optional(string)<br/>      lan_id      = optional(string)<br/>      lan_name    = optional(string)<br/>      ports       = optional(list(number))<br/>      port_ranges = optional(list(string))<br/>      subnets     = optional(list(string))<br/>    })<br/><br/>    protocols       = optional(list(string))<br/>    forward_locally = optional(bool)<br/>    unidirectional  = optional(bool)<br/>  }))</pre> | `{}` | no |
| <a name="input_site_lans"></a> [site\_lans](#input\_site\_lans) | LAN interfaces on Magic Transit sites, keyed by a stable identifier. Each LAN attaches to a site by site\_key,<br/>naming a key in var.sites, or by site\_id for a site managed elsewhere. static\_addressing configures the<br/>Cloudflare side address and, optionally, DHCP relay or a DHCP server for the subnet. | <pre>map(object({<br/>    site_key = optional(string)<br/>    site_id  = optional(string)<br/><br/>    name           = optional(string)<br/>    physport       = optional(number)<br/>    vlan_tag       = optional(number)<br/>    bond_id        = optional(number)<br/>    ha_link        = optional(bool)<br/>    is_breakout    = optional(bool)<br/>    is_prioritized = optional(bool)<br/><br/>    nat_static_prefix = optional(string)<br/><br/>    routed_subnets = optional(map(object({<br/>      prefix            = string<br/>      next_hop          = string<br/>      nat_static_prefix = optional(string)<br/>    })), {})<br/><br/>    static_addressing = optional(object({<br/>      address           = string<br/>      secondary_address = optional(string)<br/>      virtual_address   = optional(string)<br/>      dhcp_relay = optional(object({<br/>        server_addresses = optional(list(string))<br/>      }))<br/>      dhcp_server = optional(object({<br/>        dhcp_pool_start = optional(string)<br/>        dhcp_pool_end   = optional(string)<br/>        dns_server      = optional(string)<br/>        dns_servers     = optional(list(string))<br/>        reservations    = optional(map(string))<br/>        dhcp_options = optional(map(object({<br/>          code  = number<br/>          type  = string<br/>          value = string<br/>        })), {})<br/>      }))<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_site_wans"></a> [site\_wans](#input\_site\_wans) | WAN interfaces on Magic Transit sites, keyed by a stable identifier. Each WAN attaches to a site by site\_key,<br/>naming a key in var.sites, or by site\_id. physport is the physical port number on the connector. | <pre>map(object({<br/>    site_key = optional(string)<br/>    site_id  = optional(string)<br/><br/>    physport = number<br/>    name     = optional(string)<br/>    priority = optional(number)<br/>    vlan_tag = optional(number)<br/><br/>    static_addressing = optional(object({<br/>      address           = string<br/>      gateway_address   = string<br/>      secondary_address = optional(string)<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_sites"></a> [sites](#input\_sites) | Magic Transit sites, keyed by a stable identifier. The map key becomes the site name unless the object sets<br/>name explicitly. connector\_key names a key in var.connectors; connector\_id takes an existing connector ID.<br/>Set ha\_mode to run two connectors at the same site. | <pre>map(object({<br/>    name                    = optional(string)<br/>    description             = optional(string)<br/>    ha_mode                 = optional(bool)<br/>    connector_key           = optional(string)<br/>    connector_id            = optional(string)<br/>    secondary_connector_key = optional(string)<br/>    secondary_connector_id  = optional(string)<br/>    location = optional(object({<br/>      lat = optional(string)<br/>      lon = optional(string)<br/>    }))<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_connector_ids"></a> [connector\_ids](#output\_connector\_ids) | Connector IDs, keyed by the keys of var.connectors. |
| <a name="output_connector_license_keys"></a> [connector\_license\_keys](#output\_connector\_license\_keys) | License keys returned when each connector was created. Cloudflare returns these once, on creation only. |
| <a name="output_connectors"></a> [connectors](#output\_connectors) | Full cloudflare\_magic\_transit\_connector objects, keyed by the keys of var.connectors. Marked sensitive because the object carries the connector license key. |
| <a name="output_enabled"></a> [enabled](#output\_enabled) | Whether this submodule created its resources. |
| <a name="output_site_acl_ids"></a> [site\_acl\_ids](#output\_site\_acl\_ids) | ACL IDs, keyed by the keys of var.site\_acls. |
| <a name="output_site_acls"></a> [site\_acls](#output\_site\_acls) | Full cloudflare\_magic\_transit\_site\_acl objects, keyed by the keys of var.site\_acls. |
| <a name="output_site_ids"></a> [site\_ids](#output\_site\_ids) | Site IDs, keyed by the keys of var.sites. |
| <a name="output_site_lan_ids"></a> [site\_lan\_ids](#output\_site\_lan\_ids) | LAN IDs, keyed by the keys of var.site\_lans. |
| <a name="output_site_lans"></a> [site\_lans](#output\_site\_lans) | Full cloudflare\_magic\_transit\_site\_lan objects, keyed by the keys of var.site\_lans. |
| <a name="output_site_wan_ids"></a> [site\_wan\_ids](#output\_site\_wan\_ids) | WAN IDs, keyed by the keys of var.site\_wans. |
| <a name="output_site_wans"></a> [site\_wans](#output\_site\_wans) | Full cloudflare\_magic\_transit\_site\_wan objects, keyed by the keys of var.site\_wans. |
| <a name="output_sites"></a> [sites](#output\_sites) | Full cloudflare\_magic\_transit\_site objects, keyed by the keys of var.sites. |
<!-- END_TF_DOCS -->
