variable "enabled" {
  description = "Whether to create the resources managed by this submodule."
  type        = bool
  default     = true
}

variable "account_id" {
  description = "Cloudflare account ID that owns the Magic WAN tunnels and routes."
  type        = string
  default     = null

  validation {
    condition     = var.account_id == null || can(regex("^[0-9a-f]{32}$", var.account_id))
    error_message = "account_id must be a 32 character lowercase hexadecimal Cloudflare account ID."
  }
}

variable "gre_tunnels" {
  description = <<-EOT
    Magic WAN GRE tunnels, keyed by a stable identifier. The map key becomes the tunnel name unless the object
    sets name explicitly. Cloudflare caps tunnel names at 15 characters with no spaces or special characters.
    interface_address is a /31 carrying one address for each end of the tunnel.

    Magic WAN is an enterprise product. Leave this map empty unless your account is onboarded.
  EOT

  type = map(object({
    name                      = optional(string)
    cloudflare_gre_endpoint   = string
    customer_gre_endpoint     = string
    interface_address         = string
    interface_address6        = optional(string)
    description               = optional(string)
    mtu                       = optional(number)
    ttl                       = optional(number)
    automatic_return_routing  = optional(bool)
    health_check_enabled      = optional(bool)
    health_check_direction    = optional(string)
    health_check_rate         = optional(string)
    health_check_type         = optional(string)
    health_check_target_saved = optional(string)
    bgp = optional(object({
      customer_asn   = number
      extra_prefixes = optional(list(string))
      md5_key        = optional(string)
    }))
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, t in var.gre_tunnels :
      can(regex("^[A-Za-z0-9_-]{1,15}$", coalesce(t.name, k)))
    ])
    error_message = "GRE tunnel names must be 15 characters or fewer with no spaces or special characters. The map key is used when name is unset."
  }

  validation {
    condition = alltrue([
      for t in values(var.gre_tunnels) :
      can(regex("/31$", t.interface_address))
    ])
    error_message = "interface_address must be a /31 prefix, for example 10.10.10.0/31."
  }

  validation {
    condition = alltrue([
      for t in values(var.gre_tunnels) :
      t.mtu == null || t.mtu >= 576
    ])
    error_message = "mtu must be 576 or greater."
  }

  validation {
    condition = alltrue([
      for t in values(var.gre_tunnels) :
      t.health_check_direction == null || contains(["unidirectional", "bidirectional"], t.health_check_direction)
    ])
    error_message = "health_check_direction must be unidirectional or bidirectional."
  }

  validation {
    condition = alltrue([
      for t in values(var.gre_tunnels) :
      t.health_check_rate == null || contains(["low", "mid", "high"], t.health_check_rate)
    ])
    error_message = "health_check_rate must be one of low, mid, high."
  }

  validation {
    condition = alltrue([
      for t in values(var.gre_tunnels) :
      t.health_check_type == null || contains(["reply", "request"], t.health_check_type)
    ])
    error_message = "health_check_type must be reply or request."
  }
}

variable "ipsec_tunnels" {
  description = <<-EOT
    Magic WAN IPsec tunnels, keyed by a stable identifier. The map key becomes the tunnel name unless the object
    sets name explicitly.

    The pre shared key lives in the separate var.ipsec_tunnel_psks map, not here, so that this map stays free of
    sensitive values and can drive for_each. Leaving a tunnel out of that map lets Cloudflare generate the key,
    which is the recommended path.

    Magic WAN is an enterprise product. Leave this map empty unless your account is onboarded.
  EOT

  type = map(object({
    name                      = optional(string)
    cloudflare_endpoint       = string
    customer_endpoint         = optional(string)
    interface_address         = string
    interface_address6        = optional(string)
    description               = optional(string)
    replay_protection         = optional(bool)
    automatic_return_routing  = optional(bool)
    custom_remote_fqdn_id     = optional(string)
    health_check_enabled      = optional(bool)
    health_check_direction    = optional(string)
    health_check_rate         = optional(string)
    health_check_type         = optional(string)
    health_check_target_saved = optional(string)
    bgp = optional(object({
      customer_asn   = number
      extra_prefixes = optional(list(string))
      md5_key        = optional(string)
    }))
  }))
  default = {}

  validation {
    condition = alltrue([
      for t in values(var.ipsec_tunnels) :
      can(regex("/31$", t.interface_address))
    ])
    error_message = "interface_address must be a /31 prefix, for example 10.10.10.0/31."
  }

  validation {
    condition = alltrue([
      for t in values(var.ipsec_tunnels) :
      t.health_check_direction == null || contains(["unidirectional", "bidirectional"], t.health_check_direction)
    ])
    error_message = "health_check_direction must be unidirectional or bidirectional."
  }

  validation {
    condition = alltrue([
      for t in values(var.ipsec_tunnels) :
      t.health_check_rate == null || contains(["low", "mid", "high"], t.health_check_rate)
    ])
    error_message = "health_check_rate must be one of low, mid, high."
  }

  validation {
    condition = alltrue([
      for t in values(var.ipsec_tunnels) :
      t.health_check_type == null || contains(["reply", "request"], t.health_check_type)
    ])
    error_message = "health_check_type must be reply or request."
  }
}

variable "ipsec_tunnel_psks" {
  description = <<-EOT
    Pre shared keys for IPsec tunnels, keyed by the same identifiers as var.ipsec_tunnels. Omit a key and
    Cloudflare generates one for that tunnel. Anything set here is written to Terraform state, so source it from a
    secret manager rather than from a literal in version control. Kept separate from var.ipsec_tunnels so that
    map stays free of sensitive values and can drive for_each.
  EOT

  type      = map(string)
  default   = {}
  sensitive = true
}

variable "static_routes" {
  description = <<-EOT
    Magic WAN static routes, keyed by a stable identifier. Each route sends a prefix to a next hop, which is
    normally the Cloudflare side address of a GRE or IPsec tunnel. Lower priority values win.
  EOT

  type = map(object({
    prefix      = string
    nexthop     = string
    priority    = number
    description = optional(string)
    weight      = optional(number)
    scope = optional(object({
      colo_names   = optional(list(string))
      colo_regions = optional(list(string))
    }))
  }))
  default = {}

  validation {
    condition = alltrue([
      for r in values(var.static_routes) :
      can(cidrhost(r.prefix, 0))
    ])
    error_message = "Each static route prefix must be valid CIDR notation, for example 10.0.0.0/16."
  }

  validation {
    condition = alltrue([
      for r in values(var.static_routes) :
      r.priority >= 0
    ])
    error_message = "Static route priority must be zero or greater."
  }
}
