variable "enabled" {
  description = "Whether to create the resources managed by this submodule."
  type        = bool
  default     = true
}

variable "account_id" {
  description = "Cloudflare account ID that owns the load balancer monitors and monitor groups."
  type        = string
  default     = null

  validation {
    condition     = var.account_id == null || can(regex("^[0-9a-f]{32}$", var.account_id))
    error_message = "account_id must be a 32 character lowercase hexadecimal Cloudflare account ID."
  }
}

variable "zone_id" {
  description = "Cloudflare zone ID that owns the standalone health checks. Only needed when var.healthchecks is non empty."
  type        = string
  default     = null

  validation {
    condition     = var.zone_id == null || can(regex("^[0-9a-f]{32}$", var.zone_id))
    error_message = "zone_id must be a 32 character lowercase hexadecimal Cloudflare zone ID."
  }
}

variable "monitors" {
  description = <<-EOT
    Load balancer monitors to create, keyed by a stable identifier. A monitor defines how Cloudflare probes the
    origins of any pool that references it. Account scoped, so var.account_id is required when this map is non empty.
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

  validation {
    condition = alltrue([
      for m in values(var.monitors) :
      m.port == null || (m.port > 0 && m.port <= 65535)
    ])
    error_message = "Each monitor port must be between 1 and 65535."
  }

  validation {
    condition = alltrue([
      for m in values(var.monitors) :
      contains(["tcp", "udp_icmp", "smtp"], m.type) ? m.port != null : true
    ])
    error_message = "Monitors of type tcp, udp_icmp or smtp must set port."
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

  validation {
    condition = alltrue(flatten([
      for g in values(var.monitor_groups) : [
        for m in values(g.members) :
        (m.monitor_key != null) != (m.monitor_id != null)
      ]
    ]))
    error_message = "Each monitor group member must set exactly one of monitor_key or monitor_id."
  }

  validation {
    condition = alltrue(flatten([
      for g in values(var.monitor_groups) : [
        for m in values(g.members) :
        m.monitor_key == null || contains(keys(var.monitors), m.monitor_key)
      ]
    ]))
    error_message = "Every monitor group member monitor_key must name a key present in var.monitors."
  }

  validation {
    condition     = alltrue([for g in values(var.monitor_groups) : length(g.members) > 0])
    error_message = "Each monitor group must contain at least one member."
  }
}

variable "healthchecks" {
  description = <<-EOT
    Standalone zone level health checks to create, keyed by a stable identifier. These are the Cloudflare
    Health Checks product, independent of load balancing, and require var.zone_id.
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

  validation {
    condition = alltrue([
      for h in values(var.healthchecks) :
      contains(["HTTP", "HTTPS", "TCP"], h.type)
    ])
    error_message = "Each healthcheck type must be one of HTTP, HTTPS, TCP."
  }

  validation {
    condition = alltrue([
      for h in values(var.healthchecks) :
      h.http_config == null || h.http_config.method == null || contains(["GET", "HEAD"], h.http_config.method)
    ])
    error_message = "healthcheck http_config.method must be GET or HEAD."
  }

  validation {
    condition = alltrue([
      for h in values(var.healthchecks) :
      h.tcp_config == null || h.tcp_config.method == null || h.tcp_config.method == "connection_established"
    ])
    error_message = "healthcheck tcp_config.method must be connection_established."
  }

  validation {
    condition = alltrue([
      for k in keys(var.healthchecks) :
      can(regex("^[A-Za-z0-9_-]+$", k))
    ])
    error_message = "Healthcheck map keys become the Cloudflare health check name, so they may contain only alphanumeric characters, hyphens and underscores."
  }
}
