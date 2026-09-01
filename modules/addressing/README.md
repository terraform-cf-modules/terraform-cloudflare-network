# Submodule: addressing

BYOIP and address maps.

Creates `cloudflare_byo_ip_prefix` and `cloudflare_address_map`.

| Resource | Purpose |
|----------|---------|
| `cloudflare_byo_ip_prefix` | Register a customer owned prefix for Cloudflare to advertise under a given ASN |
| `cloudflare_address_map` | Pin account owned IPs to specific zones or to the whole account |

Both register intent. Cloudflare still has to approve prefix ownership out of band before it advertises a BYOIP
prefix, and an address map only affects DNS answers once `enabled` is true.

`ownership_validation_token` is exposed as a sensitive output because it proves control of the prefix.

## Usage

```hcl
module "addressing" {
  source  = "terraform-cf-modules/network/cloudflare//modules/addressing"
  version = "~> 0.1"

  enabled = true
  account_id = var.account_id

  byo_ip_prefixes = {
    primary = {
      cidr                  = "203.0.113.0/24"
      asn                   = 64512
      delegate_loa_creation = true
    }
  }

  address_maps = {
    dedicated = {
      enabled     = true
      default_sni = "example.com"
      ips         = ["203.0.113.10", "203.0.113.11"]

      memberships = {
        zone = { identifier = var.zone_id, kind = "zone" }
      }
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
| [cloudflare_address_map.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/address_map) | resource |
| [cloudflare_byo_ip_prefix.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/byo_ip_prefix) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Cloudflare account ID that owns the prefixes and address maps. | `string` | `null` | no |
| <a name="input_address_maps"></a> [address\_maps](#input\_address\_maps) | Address maps to create, keyed by a stable identifier. An address map pins a set of account owned IPs to<br/>specific zones or to the whole account, so Cloudflare DNS answers with those addresses instead of shared<br/>anycast space. A map only takes effect once enabled is true. | <pre>map(object({<br/>    description = optional(string)<br/>    enabled     = optional(bool, false)<br/>    default_sni = optional(string)<br/>    ips         = optional(list(string))<br/>    memberships = optional(map(object({<br/>      identifier = string<br/>      kind       = string<br/>    })), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_byo_ip_prefixes"></a> [byo\_ip\_prefixes](#input\_byo\_ip\_prefixes) | Bring Your Own IP prefixes to onboard, keyed by a stable identifier. Cloudflare will advertise the prefix under<br/>the given ASN once it has approved ownership, which is a manual review outside Terraform. Creating the resource<br/>only registers the prefix. | <pre>map(object({<br/>    cidr                  = string<br/>    asn                   = number<br/>    description           = optional(string)<br/>    delegate_loa_creation = optional(bool)<br/>    loa_document_id       = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Whether to create the resources managed by this submodule. | `bool` | `true` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_address_map_ids"></a> [address\_map\_ids](#output\_address\_map\_ids) | Address map IDs, keyed by the keys of var.address\_maps. |
| <a name="output_address_maps"></a> [address\_maps](#output\_address\_maps) | Full cloudflare\_address\_map objects, keyed by the keys of var.address\_maps. |
| <a name="output_byo_ip_prefix_ids"></a> [byo\_ip\_prefix\_ids](#output\_byo\_ip\_prefix\_ids) | BYOIP prefix IDs, keyed by the keys of var.byo\_ip\_prefixes. |
| <a name="output_byo_ip_prefix_validation_tokens"></a> [byo\_ip\_prefix\_validation\_tokens](#output\_byo\_ip\_prefix\_validation\_tokens) | Ownership validation tokens for each registered prefix, keyed by the keys of var.byo\_ip\_prefixes. |
| <a name="output_byo_ip_prefixes"></a> [byo\_ip\_prefixes](#output\_byo\_ip\_prefixes) | Full cloudflare\_byo\_ip\_prefix objects, keyed by the keys of var.byo\_ip\_prefixes. |
| <a name="output_enabled"></a> [enabled](#output\_enabled) | Whether this submodule created its resources. |
<!-- END_TF_DOCS -->
