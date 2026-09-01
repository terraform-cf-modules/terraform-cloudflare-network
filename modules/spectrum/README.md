# Submodule: spectrum

Spectrum applications.

Creates `cloudflare_spectrum_application`: Cloudflare proxying arbitrary TCP and UDP traffic, not just HTTP.

`protocol` is a port specification at Cloudflare's edge, such as `tcp/22` or `tcp/1000-2000`. Traffic goes to
either `origin_direct` (a list of origin addresses) or `origin_dns` plus an origin port.

The provider types the origin port as a dynamic value: an integer for a single port, a string for a range. A
Terraform object type constraint unifies every element of a map to one type, so a single input cannot carry both
forms. This submodule takes them as two fields, `origin_port` and `origin_port_range`, and splits the
applications across two resource blocks internally. The outputs merge them back into one map keyed exactly as
you supplied it, so this is invisible from the outside. Set at most one of the two per application.

## Usage

```hcl
module "spectrum" {
  source  = "terraform-cf-modules/network/cloudflare//modules/spectrum"
  version = "~> 0.1"

  enabled = true
  zone_id = var.zone_id

  applications = {
    ssh = {
      protocol      = "tcp/22"
      dns           = { type = "CNAME", name = "ssh.example.com" }
      origin_direct = ["tcp://192.0.2.10:22"]

      argo_smart_routing = true
      ip_firewall        = true
      proxy_protocol     = "v2"
      edge_ips           = { type = "dynamic", connectivity = "all" }
    }

    game = {
      protocol   = "tcp/25565-25575"
      dns        = { type = "CNAME", name = "game.example.com" }
      origin_dns = { name = "origin.example.net", type = "A", ttl = 600 }

      origin_port_range = "25565-25575"
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_applications"></a> [applications](#input\_applications) | Spectrum applications to create, keyed by a stable identifier. Spectrum proxies arbitrary TCP and UDP traffic<br/>through Cloudflare, so protocol is a port specification such as "tcp/22" or "tcp/3000-3010".<br/><br/>Send traffic to either origin\_direct (a list of origin IPs) or origin\_dns plus an origin port. Because the<br/>provider models the origin port as a dynamic value, a single port goes in origin\_port and a range goes in<br/>origin\_port\_range. Set at most one of the two. | <pre>map(object({<br/>    protocol = string<br/><br/>    dns = object({<br/>      name = optional(string)<br/>      type = optional(string, "CNAME")<br/>    })<br/><br/>    origin_direct     = optional(list(string))<br/>    origin_port       = optional(number)<br/>    origin_port_range = optional(string)<br/><br/>    origin_dns = optional(object({<br/>      name = optional(string)<br/>      ttl  = optional(number)<br/>      type = optional(string)<br/>    }))<br/><br/>    edge_ips = optional(object({<br/>      connectivity = optional(string)<br/>      ips          = optional(list(string))<br/>      type         = optional(string)<br/>    }))<br/><br/>    argo_smart_routing = optional(bool)<br/>    ip_firewall        = optional(bool)<br/>    proxy_protocol     = optional(string)<br/>    tls                = optional(string)<br/>    traffic_type       = optional(string)<br/>    virtual_network_id = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Whether to create the resources managed by this submodule. | `bool` | `true` | no |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Cloudflare zone ID that owns the Spectrum applications. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_application_ids"></a> [application\_ids](#output\_application\_ids) | Spectrum application IDs, keyed by the keys of var.applications. |
| <a name="output_applications"></a> [applications](#output\_applications) | Full cloudflare\_spectrum\_application objects, keyed by the keys of var.applications. |
| <a name="output_enabled"></a> [enabled](#output\_enabled) | Whether this submodule created its resources. |
<!-- END_TF_DOCS -->
