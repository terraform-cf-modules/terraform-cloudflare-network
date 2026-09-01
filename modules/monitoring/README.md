# Submodule: monitoring

Magic Network Monitoring.

Creates the Magic Network Monitoring configuration and its alert rules.

| Resource | Purpose |
|----------|---------|
| `cloudflare_magic_network_monitoring_configuration` | Account wide flow collection settings |
| `cloudflare_magic_network_monitoring_rule` | Threshold, zscore, and advanced DDoS alert rules |

Magic Network Monitoring analyses NetFlow or sFlow exported by your routers. `default_sampling` must match the
packet sampling rate those routers are configured with, or every threshold will be wrong by that factor.

There is exactly one configuration per account, so `var.configuration` is a single object rather than a map.
Leave it null to manage the rules alone.

## Usage

```hcl
module "monitoring" {
  source  = "terraform-cf-modules/network/cloudflare//modules/monitoring"
  version = "~> 0.1"

  enabled = true
  account_id = var.account_id

  configuration = {
    name             = "example-account"
    default_sampling = 10000
    router_ips       = ["203.0.113.1"]
  }

  rules = {
    inbound_flood = {
      type                = "threshold"
      prefixes            = ["203.0.113.0/24"]
      bandwidth_threshold = 1000000000
      duration            = "5m"
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Cloudflare account ID that owns the Magic Network Monitoring configuration and rules. | `string` | `null` | no |
| <a name="input_configuration"></a> [configuration](#input\_configuration) | Magic Network Monitoring configuration for the account. There is exactly one per account, so this is a single<br/>object rather than a map. Leave it null to manage the rules only. default\_sampling must match the packet<br/>sampling rate configured on the routers that export flow data. | <pre>object({<br/>    name             = string<br/>    default_sampling = optional(number)<br/>    router_ips       = optional(list(string))<br/>    warp_devices = optional(map(object({<br/>      id        = string<br/>      name      = string<br/>      router_ip = string<br/>    })), {})<br/>  })</pre> | `null` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Whether to create the resources managed by this submodule. | `bool` | `true` | no |
| <a name="input_rules"></a> [rules](#input\_rules) | Magic Network Monitoring rules, keyed by a stable identifier. The map key becomes the rule name unless the<br/>object sets name explicitly. A threshold rule needs bandwidth\_threshold or packet\_threshold; a zscore rule<br/>uses zscore\_sensitivity and zscore\_target instead. | <pre>map(object({<br/>    name                    = optional(string)<br/>    type                    = string<br/>    prefixes                = list(string)<br/>    automatic_advertisement = optional(bool, false)<br/>    bandwidth_threshold     = optional(number)<br/>    packet_threshold        = optional(number)<br/>    duration                = optional(string)<br/>    prefix_match            = optional(string)<br/>    zscore_sensitivity      = optional(string)<br/>    zscore_target           = optional(string)<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_configuration"></a> [configuration](#output\_configuration) | The cloudflare\_magic\_network\_monitoring\_configuration object, or null when var.configuration is unset. |
| <a name="output_enabled"></a> [enabled](#output\_enabled) | Whether this submodule created its resources. |
| <a name="output_rule_ids"></a> [rule\_ids](#output\_rule\_ids) | Magic Network Monitoring rule IDs, keyed by the keys of var.rules. |
| <a name="output_rules"></a> [rules](#output\_rules) | Full cloudflare\_magic\_network\_monitoring\_rule objects, keyed by the keys of var.rules. |
<!-- END_TF_DOCS -->
