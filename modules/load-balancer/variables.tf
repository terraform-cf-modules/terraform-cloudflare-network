variable "enabled" {
  description = "Whether to create the resources managed by this submodule."
  type        = bool
  default     = true
}

variable "zone_id" {
  description = "Cloudflare zone ID that owns the load balancers. Load balancers are zone scoped even though their pools are account scoped."
  type        = string
  default     = null

  validation {
    condition     = var.zone_id == null || can(regex("^[0-9a-f]{32}$", var.zone_id))
    error_message = "zone_id must be a 32 character lowercase hexadecimal Cloudflare zone ID."
  }
}

variable "load_balancers" {
  description = <<-EOT
    Load balancers to create, keyed by a stable identifier. The map key becomes the DNS hostname unless the object
    sets name explicitly.

    default_pools and fallback_pool take pool IDs. region_pools, country_pools and pop_pools map a region code,
    two letter country code or Cloudflare PoP code to an ordered list of pool IDs and are only consulted when
    steering_policy is geo. The root module of this repository resolves pool keys to IDs for you.
  EOT

  type = map(object({
    name          = optional(string)
    default_pools = list(string)
    fallback_pool = string

    description = optional(string)
    enabled     = optional(bool, true)
    proxied     = optional(bool)
    ttl         = optional(number)
    networks    = optional(list(string))

    steering_policy      = optional(string)
    session_affinity     = optional(string)
    session_affinity_ttl = optional(number)

    region_pools  = optional(map(list(string)))
    country_pools = optional(map(list(string)))
    pop_pools     = optional(map(list(string)))

    adaptive_routing = optional(object({
      failover_across_pools = optional(bool)
    }))

    location_strategy = optional(object({
      mode       = optional(string)
      prefer_ecs = optional(string)
    }))

    random_steering = optional(object({
      default_weight = optional(number)
      pool_weights   = optional(map(number))
    }))

    session_affinity_attributes = optional(object({
      drain_duration         = optional(number)
      headers                = optional(list(string))
      require_all_headers    = optional(bool)
      samesite               = optional(string)
      secure                 = optional(string)
      zero_downtime_failover = optional(string)
    }))

    # BETA in the Cloudflare API and not generally available. Rules are ordered
    # by priority, so they are taken as a map and sorted by key for stability.
    rules = optional(map(object({
      name       = optional(string)
      condition  = optional(string)
      disabled   = optional(bool)
      priority   = optional(number)
      terminates = optional(bool)

      fixed_response = optional(object({
        content_type = optional(string)
        location     = optional(string)
        message_body = optional(string)
        status_code  = optional(number)
      }))

      overrides = optional(object({
        default_pools        = optional(list(string))
        fallback_pool        = optional(string)
        region_pools         = optional(map(list(string)))
        country_pools        = optional(map(list(string)))
        pop_pools            = optional(map(list(string)))
        steering_policy      = optional(string)
        session_affinity     = optional(string)
        session_affinity_ttl = optional(number)
        ttl                  = optional(number)

        adaptive_routing = optional(object({
          failover_across_pools = optional(bool)
        }))
        location_strategy = optional(object({
          mode       = optional(string)
          prefer_ecs = optional(string)
        }))
        random_steering = optional(object({
          default_weight = optional(number)
          pool_weights   = optional(map(number))
        }))
        session_affinity_attributes = optional(object({
          drain_duration         = optional(number)
          headers                = optional(list(string))
          require_all_headers    = optional(bool)
          samesite               = optional(string)
          secure                 = optional(string)
          zero_downtime_failover = optional(string)
        }))
      }))
    })), {})
  }))
  default = {}

  validation {
    condition     = alltrue([for lb in values(var.load_balancers) : length(lb.default_pools) > 0])
    error_message = "Each load balancer must list at least one pool in default_pools."
  }

  validation {
    condition = alltrue([
      for lb in values(var.load_balancers) :
      lb.steering_policy == null || contains(
        ["off", "geo", "random", "dynamic_latency", "proximity", "least_outstanding_requests", "least_connections", ""],
        lb.steering_policy
      )
    ])
    error_message = "steering_policy must be one of off, geo, random, dynamic_latency, proximity, least_outstanding_requests, least_connections, or the empty string."
  }

  validation {
    condition = alltrue([
      for lb in values(var.load_balancers) :
      lb.session_affinity == null || contains(["none", "cookie", "ip_cookie", "header"], lb.session_affinity)
    ])
    error_message = "session_affinity must be one of none, cookie, ip_cookie, header."
  }

  validation {
    condition = alltrue([
      for lb in values(var.load_balancers) :
      lb.session_affinity != "header" || (
        lb.session_affinity_attributes != null &&
        length(coalesce(try(lb.session_affinity_attributes.headers, null), [])) > 0
      )
    ])
    error_message = "session_affinity set to header requires at least one entry in session_affinity_attributes.headers."
  }

  validation {
    condition = alltrue([
      for lb in values(var.load_balancers) :
      lb.session_affinity_attributes == null || lb.session_affinity_attributes.samesite == null ||
      contains(["Auto", "Lax", "None", "Strict"], lb.session_affinity_attributes.samesite)
    ])
    error_message = "session_affinity_attributes.samesite must be one of Auto, Lax, None, Strict."
  }

  validation {
    condition = alltrue([
      for lb in values(var.load_balancers) :
      lb.session_affinity_attributes == null || lb.session_affinity_attributes.secure == null ||
      contains(["Auto", "Always", "Never"], lb.session_affinity_attributes.secure)
    ])
    error_message = "session_affinity_attributes.secure must be one of Auto, Always, Never."
  }

  validation {
    condition = alltrue([
      for lb in values(var.load_balancers) :
      lb.session_affinity_attributes == null || lb.session_affinity_attributes.zero_downtime_failover == null ||
      contains(["none", "temporary", "sticky"], lb.session_affinity_attributes.zero_downtime_failover)
    ])
    error_message = "session_affinity_attributes.zero_downtime_failover must be one of none, temporary, sticky."
  }

  validation {
    condition = alltrue([
      for lb in values(var.load_balancers) :
      lb.location_strategy == null || lb.location_strategy.mode == null ||
      contains(["pop", "resolver_ip"], lb.location_strategy.mode)
    ])
    error_message = "location_strategy.mode must be pop or resolver_ip."
  }

  validation {
    condition = alltrue([
      for lb in values(var.load_balancers) :
      lb.location_strategy == null || lb.location_strategy.prefer_ecs == null ||
      contains(["always", "never", "proximity", "geo"], lb.location_strategy.prefer_ecs)
    ])
    error_message = "location_strategy.prefer_ecs must be one of always, never, proximity, geo."
  }

  validation {
    condition = alltrue([
      for lb in values(var.load_balancers) :
      alltrue([for cc in keys(coalesce(lb.country_pools, {})) : can(regex("^[A-Z]{2}$", cc))])
    ])
    error_message = "country_pools keys must be two letter uppercase ISO 3166-1 alpha-2 country codes."
  }

  validation {
    condition = alltrue([
      for lb in values(var.load_balancers) :
      lb.ttl == null || lb.proxied != true
    ])
    error_message = "ttl only applies to unproxied load balancers, so do not set it together with proxied = true."
  }

  validation {
    condition = alltrue(flatten([
      for lb in values(var.load_balancers) : [
        for r in values(lb.rules) :
        r.overrides == null || r.fixed_response == null
      ]
    ]))
    error_message = "A load balancer rule may set fixed_response or overrides, not both."
  }

  validation {
    condition = alltrue(flatten([
      for lb in values(var.load_balancers) : [
        for r in values(lb.rules) :
        r.overrides == null || r.overrides.steering_policy == null || contains(
          ["off", "geo", "random", "dynamic_latency", "proximity", "least_outstanding_requests", "least_connections", ""],
          r.overrides.steering_policy
        )
      ]
    ]))
    error_message = "Rule overrides.steering_policy must be one of off, geo, random, dynamic_latency, proximity, least_outstanding_requests, least_connections, or the empty string."
  }

  validation {
    condition = alltrue(flatten([
      for lb in values(var.load_balancers) : [
        for r in values(lb.rules) :
        r.overrides == null || r.overrides.session_affinity == null ||
        contains(["none", "cookie", "ip_cookie", "header"], r.overrides.session_affinity)
      ]
    ]))
    error_message = "Rule overrides.session_affinity must be one of none, cookie, ip_cookie, header."
  }
}
