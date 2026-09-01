# Wrapper

Creates many instances of the root module from a single map, so a list of similar resources does not need a
repeated `module` block per item.

```hcl
module "instances" {
  source = "terraform-cf-modules/network/cloudflare//wrappers"

  defaults = {
    account_id = var.account_id
  }

  items = {
    first  = { zone_id = var.zone_a }
    second = { zone_id = var.zone_b, enabled = false }
  }
}
```

Keys in `items` become the state addresses, so keep them stable. Renaming a key destroys and recreates that
instance.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | ~> 5.24 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_wrapper"></a> [wrapper](#module\_wrapper) | ../ | n/a |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_defaults"></a> [defaults](#input\_defaults) | Values applied to every item unless the item overrides them. | `any` | `{}` | no |
| <a name="input_items"></a> [items](#input\_items) | Map of module instances to create, keyed by a stable identifier. | `any` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_wrapper"></a> [wrapper](#output\_wrapper) | Map of module outputs, keyed by the same keys as var.items. |
<!-- END_TF_DOCS -->
