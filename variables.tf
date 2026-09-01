# -----------------------------------------------------------------------------
# Common inputs. Every module in this organisation exposes these.
# -----------------------------------------------------------------------------

variable "enabled" {
  description = "Whether to create the resources managed by this module. Set to false to disable the module without removing the block."
  type        = bool
  default     = true
}

variable "account_id" {
  description = "Cloudflare account ID that owns the resources. Load balancer monitors, monitor groups and pools are account scoped, so this is required whenever var.monitors, var.monitor_groups or var.pools is non empty."
  type        = string
  default     = null

  validation {
    condition     = var.account_id == null || can(regex("^[0-9a-f]{32}$", var.account_id))
    error_message = "account_id must be a 32 character lowercase hexadecimal Cloudflare account ID."
  }
}

variable "zone_id" {
  description = "Cloudflare zone ID that owns the resources. Load balancers and standalone health checks are zone scoped, so this is required whenever var.load_balancers or var.healthchecks is non empty."
  type        = string
  default     = null

  validation {
    condition     = var.zone_id == null || can(regex("^[0-9a-f]{32}$", var.zone_id))
    error_message = "zone_id must be a 32 character lowercase hexadecimal Cloudflare zone ID."
  }
}

# -----------------------------------------------------------------------------
# Health checking
# -----------------------------------------------------------------------------

variable "monitors" {
  description = <<-EOT
    Load balancer monitors to create, keyed by a stable identifier. A monitor defines how Cloudflare probes the
    origins of any pool that references it. Reference a monitor from a pool by putting its key in the pool's
    monitor field; this module resolves keys to IDs.
  EOT

  type = map(object({
    type             = optional(string, "http")
    description      = optional(string)
    method           = optional(string)
    path             = optional(string)
    port             = optional(number)
    interval         = optional(number)
    timeout          = optional(number)
    retries          = optional(number)
    consecutive_up   = optional(number)
    consecutive_down = optional(number)
    expected_body    = optional(string)
    expected_codes   = optional(string)
    follow_redirects = optional(bool)
    allow_insecure   = optional(bool)
    probe_zone       = optional(string)
    header           = optional(map(list(string)))
  }))
  default = {}

  validation {
    condition = alltrue([
      for m in values(var.monitors) :
      contains(["http", "https", "tcp", "udp_icmp", "icmp_ping", "smtp"], m.type)
    ])
    error_message = "Each monitor type must be one of http, https, tcp, udp_icmp, icmp_ping, smtp."
  }
}

variable "monitor_groups" {
  description = <<-EOT
    Load balancer monitor groups to create, keyed by a stable identifier. A monitor group bundles several monitors
    so a pool can be judged healthy or unhealthy from more than one probe. Each member either names a key in
    var.monitors through monitor_key, or supplies an existing monitor ID through monitor_id.
  EOT

  type = map(object({
    description = string
    members = map(object({
      monitor_key     = optional(string)
      monitor_id      = optional(string)
      enabled         = optional(bool, true)
      monitoring_only = optional(bool, false)
      must_be_healthy = optional(bool, true)
    }))
  }))
  default = {}
}

variable "healthchecks" {
  description = <<-EOT
    Standalone zone level health checks to create, keyed by a stable identifier. These are the Cloudflare Health
    Checks product, independent of load balancing. The map key becomes the check name unless the object sets name.
  EOT

  type = map(object({
    address               = string
    name                  = optional(string)
    type                  = optional(string, "HTTP")
    description           = optional(string)
    check_regions         = optional(list(string))
    consecutive_fails     = optional(number)
    consecutive_successes = optional(number)
    interval              = optional(number)
    retries               = optional(number)
    timeout               = optional(number)
    suspended             = optional(bool)
    http_config = optional(object({
      allow_insecure   = optional(bool)
      expected_body    = optional(string)
      expected_codes   = optional(list(string))
      follow_redirects = optional(bool)
      header           = optional(map(list(string)))
      method           = optional(string)
      path             = optional(string)
      port             = optional(number)
    }))
    tcp_config = optional(object({
      method = optional(string)
      port   = optional(number)
    }))
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# Pools
# -----------------------------------------------------------------------------

variable "pools" {
  description = <<-EOT
    Load balancer pools to create, keyed by a stable identifier. The map key becomes the pool name unless the
    object sets name explicitly.

    monitor and monitor_group each accept either a key from var.monitors or var.monitor_groups, or a literal
    Cloudflare ID for something managed elsewhere. Anything that matches a key is resolved to the created ID;
    anything else is passed through unchanged.
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
    condition     = alltrue([for p in values(var.pools) : length(p.origins) > 0])
    error_message = "Each pool must define at least one origin."
  }

  validation {
    condition = alltrue([
      for p in values(var.pools) :
      !(p.monitor != null && p.monitor_group != null)
    ])
    error_message = "Set at most one of monitor and monitor_group on each pool. Cloudflare uses one health source per pool."
  }
}

# -----------------------------------------------------------------------------
# Load balancers
# -----------------------------------------------------------------------------

variable "load_balancers" {
  description = <<-EOT
    Load balancers to create, keyed by a stable identifier. The map key becomes the DNS hostname unless the object
    sets name explicitly.

    Every pool reference (default_pools, fallback_pool, region_pools, country_pools, pop_pools and the same fields
    inside rule overrides) accepts either a key from var.pools or a literal Cloudflare pool ID. Anything that
    matches a key is resolved to the created ID; anything else is passed through unchanged.

    steering_policy decides which of those maps is consulted. Set it to geo to use region_pools, country_pools and
    pop_pools; leave it off or unset to use default_pools alone.
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
      lb.steering_policy != "geo" || anytrue([
        length(coalesce(lb.region_pools, {})) > 0,
        length(coalesce(lb.country_pools, {})) > 0,
        length(coalesce(lb.pop_pools, {})) > 0,
      ])
    ])
    error_message = "steering_policy set to geo needs at least one of region_pools, country_pools or pop_pools populated, otherwise every request falls back to default_pools."
  }
}
