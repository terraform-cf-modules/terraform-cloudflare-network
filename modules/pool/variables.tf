variable "enabled" {
  description = "Whether to create the resources managed by this submodule."
  type        = bool
  default     = true
}

variable "account_id" {
  description = "Cloudflare account ID that owns the pools. Load balancer pools are always account scoped."
  type        = string
  default     = null

  validation {
    condition     = var.account_id == null || can(regex("^[0-9a-f]{32}$", var.account_id))
    error_message = "account_id must be a 32 character lowercase hexadecimal Cloudflare account ID."
  }
}

variable "pools" {
  description = <<-EOT
    Load balancer pools to create, keyed by a stable identifier. The map key becomes the pool name unless the
    object sets name explicitly, so keys must be alphanumeric with hyphens or underscores. Each pool holds one or
    more origins and optionally references a monitor or monitor group that decides origin health.
  EOT

  type = map(object({
    name        = optional(string)
    description = optional(string)
    enabled     = optional(bool, true)

    origins = map(object({
      address            = string
      name               = optional(string)
      enabled            = optional(bool, true)
      port               = optional(number)
      weight             = optional(number)
      flatten_cname      = optional(bool)
      virtual_network_id = optional(string)
      host_header        = optional(string)
    }))

    monitor            = optional(string)
    monitor_group      = optional(string)
    minimum_origins    = optional(number)
    check_regions      = optional(list(string))
    health_sources     = optional(list(string))
    latitude           = optional(number)
    longitude          = optional(number)
    notification_email = optional(string)

    origin_steering = optional(object({
      policy = optional(string)
    }))

    load_shedding = optional(object({
      default_percent = optional(number)
      default_policy  = optional(string)
      session_percent = optional(number)
      session_policy  = optional(string)
    }))

    notification_filter = optional(object({
      origin = optional(object({
        disable = optional(bool)
        healthy = optional(bool)
      }))
      pool = optional(object({
        disable = optional(bool)
        healthy = optional(bool)
      }))
    }))
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, p in var.pools :
      can(regex("^[A-Za-z0-9_-]+$", coalesce(p.name, k)))
    ])
    error_message = "Pool names may contain only alphanumeric characters, hyphens and underscores. The map key is used when name is unset."
  }

  validation {
    condition     = alltrue([for p in values(var.pools) : length(p.origins) > 0])
    error_message = "Each pool must define at least one origin."
  }

  validation {
    condition = alltrue([
      for p in values(var.pools) :
      p.minimum_origins == null || p.minimum_origins >= 0
    ])
    error_message = "minimum_origins must be zero or greater."
  }

  validation {
    condition = alltrue([
      for p in values(var.pools) :
      p.origin_steering == null || p.origin_steering.policy == null ||
      contains(["random", "hash", "least_outstanding_requests", "least_connections"], p.origin_steering.policy)
    ])
    error_message = "origin_steering.policy must be one of random, hash, least_outstanding_requests, least_connections."
  }

  validation {
    condition = alltrue([
      for p in values(var.pools) :
      p.load_shedding == null || p.load_shedding.default_policy == null ||
      contains(["random", "hash"], p.load_shedding.default_policy)
    ])
    error_message = "load_shedding.default_policy must be random or hash."
  }

  validation {
    condition = alltrue([
      for p in values(var.pools) :
      p.load_shedding == null || p.load_shedding.session_policy == null ||
      p.load_shedding.session_policy == "hash"
    ])
    error_message = "load_shedding.session_policy only supports hash."
  }

  validation {
    condition = alltrue([
      for p in values(var.pools) :
      p.load_shedding == null || alltrue([
        for pct in [p.load_shedding.default_percent, p.load_shedding.session_percent] :
        pct == null || (pct >= 0 && pct <= 100)
      ])
    ])
    error_message = "load_shedding percentages must be between 0 and 100."
  }

  validation {
    condition = alltrue([
      for p in values(var.pools) :
      p.health_sources == null || join(",", p.health_sources) == "regional,global"
    ])
    error_message = "health_sources must be unset or exactly [\"regional\", \"global\"]. The provider rejects any other combination."
  }

  validation {
    condition = alltrue([
      for p in values(var.pools) :
      p.health_sources == null || length(coalesce(p.check_regions, [])) > 0
    ])
    error_message = "Setting health_sources to regional requires at least one entry in check_regions."
  }

  validation {
    condition = alltrue([
      for p in values(var.pools) :
      (p.latitude == null) == (p.longitude == null)
    ])
    error_message = "latitude and longitude must be set together or both left unset."
  }

  validation {
    condition = alltrue(flatten([
      for p in values(var.pools) : [
        for o in values(p.origins) :
        o.port == null || (o.port >= 0 && o.port <= 65535)
      ]
    ]))
    error_message = "Each origin port must be between 0 and 65535. Zero means the default port for the protocol."
  }
}
