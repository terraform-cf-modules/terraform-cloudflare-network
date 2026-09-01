variable "enabled" {
  description = "Whether to create the resources managed by this submodule."
  type        = bool
  default     = true
}

variable "account_id" {
  description = "Cloudflare account ID that owns the Magic Network Monitoring configuration and rules."
  type        = string
  default     = null

  validation {
    condition     = var.account_id == null || can(regex("^[0-9a-f]{32}$", var.account_id))
    error_message = "account_id must be a 32 character lowercase hexadecimal Cloudflare account ID."
  }
}

variable "configuration" {
  description = <<-EOT
    Magic Network Monitoring configuration for the account. There is exactly one per account, so this is a single
    object rather than a map. Leave it null to manage the rules only. default_sampling must match the packet
    sampling rate configured on the routers that export flow data.
  EOT

  type = object({
    name             = string
    default_sampling = optional(number)
    router_ips       = optional(list(string))
    warp_devices = optional(map(object({
      id        = string
      name      = string
      router_ip = string
    })), {})
  })
  default = null

  validation {
    condition     = var.configuration == null || try(var.configuration.default_sampling, null) == null || try(var.configuration.default_sampling, 1) >= 1
    error_message = "default_sampling must be one or greater."
  }

  validation {
    condition = var.configuration == null || alltrue([
      for device in values(try(var.configuration.warp_devices, {})) :
      can(regex("/32$", device.router_ip))
    ])
    error_message = "Each warp device router_ip must be an IPv4 CIDR ending in /32. Cloudflare only supports /32 here."
  }
}

variable "rules" {
  description = <<-EOT
    Magic Network Monitoring rules, keyed by a stable identifier. The map key becomes the rule name unless the
    object sets name explicitly. A threshold rule needs bandwidth_threshold or packet_threshold; a zscore rule
    uses zscore_sensitivity and zscore_target instead.
  EOT

  type = map(object({
    name                    = optional(string)
    type                    = string
    prefixes                = list(string)
    automatic_advertisement = optional(bool, false)
    bandwidth_threshold     = optional(number)
    packet_threshold        = optional(number)
    duration                = optional(string)
    prefix_match            = optional(string)
    zscore_sensitivity      = optional(string)
    zscore_target           = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for r in values(var.rules) :
      contains(["threshold", "zscore", "advanced_ddos"], r.type)
    ])
    error_message = "Each rule type must be one of threshold, zscore, advanced_ddos."
  }

  validation {
    condition = alltrue([
      for r in values(var.rules) :
      r.duration == null || contains(["1m", "5m", "10m", "15m", "20m", "30m", "45m", "60m"], r.duration)
    ])
    error_message = "duration must be one of 1m, 5m, 10m, 15m, 20m, 30m, 45m, 60m."
  }

  validation {
    condition = alltrue([
      for r in values(var.rules) :
      r.prefix_match == null || contains(["exact", "subnet", "supernet"], r.prefix_match)
    ])
    error_message = "prefix_match must be one of exact, subnet, supernet."
  }

  validation {
    condition = alltrue([
      for r in values(var.rules) :
      r.zscore_sensitivity == null || contains(["low", "medium", "high"], r.zscore_sensitivity)
    ])
    error_message = "zscore_sensitivity must be one of low, medium, high."
  }

  validation {
    condition = alltrue([
      for r in values(var.rules) :
      r.zscore_target == null || contains(["bits", "packets"], r.zscore_target)
    ])
    error_message = "zscore_target must be bits or packets."
  }

  validation {
    condition = alltrue([
      for r in values(var.rules) :
      r.type != "threshold" || r.bandwidth_threshold != null || r.packet_threshold != null
    ])
    error_message = "A rule of type threshold must set bandwidth_threshold or packet_threshold."
  }

  validation {
    condition = alltrue([
      for k, r in var.rules :
      can(regex("^[A-Za-z0-9_.~-]{1,256}$", coalesce(r.name, k)))
    ])
    error_message = "Rule names may contain only A-Z, a-z, 0-9, underscore, dash, period and tilde, with no spaces, up to 256 characters. The map key is used when name is unset."
  }

  validation {
    condition     = alltrue([for r in values(var.rules) : length(r.prefixes) > 0])
    error_message = "Each rule must list at least one prefix."
  }
}
