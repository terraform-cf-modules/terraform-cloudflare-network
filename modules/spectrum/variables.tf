variable "enabled" {
  description = "Whether to create the resources managed by this submodule."
  type        = bool
  default     = true
}

variable "zone_id" {
  description = "Cloudflare zone ID that owns the Spectrum applications."
  type        = string
  default     = null

  validation {
    condition     = var.zone_id == null || can(regex("^[0-9a-f]{32}$", var.zone_id))
    error_message = "zone_id must be a 32 character lowercase hexadecimal Cloudflare zone ID."
  }
}

variable "applications" {
  description = <<-EOT
    Spectrum applications to create, keyed by a stable identifier. Spectrum proxies arbitrary TCP and UDP traffic
    through Cloudflare, so protocol is a port specification such as "tcp/22" or "tcp/3000-3010".

    Send traffic to either origin_direct (a list of origin IPs) or origin_dns plus an origin port. Because the
    provider models the origin port as a dynamic value, a single port goes in origin_port and a range goes in
    origin_port_range. Set at most one of the two.
  EOT

  type = map(object({
    protocol = string

    dns = object({
      name = optional(string)
      type = optional(string, "CNAME")
    })

    origin_direct     = optional(list(string))
    origin_port       = optional(number)
    origin_port_range = optional(string)

    origin_dns = optional(object({
      name = optional(string)
      ttl  = optional(number)
      type = optional(string)
    }))

    edge_ips = optional(object({
      connectivity = optional(string)
      ips          = optional(list(string))
      type         = optional(string)
    }))

    argo_smart_routing = optional(bool)
    ip_firewall        = optional(bool)
    proxy_protocol     = optional(string)
    tls                = optional(string)
    traffic_type       = optional(string)
    virtual_network_id = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for a in values(var.applications) :
      can(regex("^(tcp|udp)/[0-9]+(-[0-9]+)?$", a.protocol))
    ])
    error_message = "protocol must look like tcp/1000 or tcp/1000-2000, using tcp or udp."
  }

  validation {
    condition = alltrue([
      for a in values(var.applications) :
      contains(["CNAME", "ADDRESS"], a.dns.type)
    ])
    error_message = "dns.type must be CNAME or ADDRESS."
  }

  validation {
    condition = alltrue([
      for a in values(var.applications) :
      a.origin_dns == null || a.origin_dns.type == null || contains(["", "A", "AAAA", "SRV"], a.origin_dns.type)
    ])
    error_message = "origin_dns.type must be one of the empty string, A, AAAA, SRV."
  }

  validation {
    condition = alltrue([
      for a in values(var.applications) :
      a.edge_ips == null || a.edge_ips.type == null || contains(["dynamic", "static"], a.edge_ips.type)
    ])
    error_message = "edge_ips.type must be dynamic or static."
  }

  validation {
    condition = alltrue([
      for a in values(var.applications) :
      a.edge_ips == null || a.edge_ips.connectivity == null || contains(["all", "ipv4", "ipv6"], a.edge_ips.connectivity)
    ])
    error_message = "edge_ips.connectivity must be one of all, ipv4, ipv6."
  }

  validation {
    condition = alltrue([
      for a in values(var.applications) :
      a.tls == null || contains(["off", "flexible", "full", "strict"], a.tls)
    ])
    error_message = "tls must be one of off, flexible, full, strict."
  }

  validation {
    condition = alltrue([
      for a in values(var.applications) :
      a.traffic_type == null || contains(["direct", "http", "https"], a.traffic_type)
    ])
    error_message = "traffic_type must be one of direct, http, https."
  }

  validation {
    condition = alltrue([
      for a in values(var.applications) :
      a.proxy_protocol == null || contains(["off", "v1", "v2", "simple"], a.proxy_protocol)
    ])
    error_message = "proxy_protocol must be one of off, v1, v2, simple."
  }

  validation {
    condition = alltrue([
      for a in values(var.applications) :
      !(a.origin_port != null && a.origin_port_range != null)
    ])
    error_message = "Set at most one of origin_port and origin_port_range on each application."
  }

  validation {
    condition = alltrue([
      for a in values(var.applications) :
      a.origin_port_range == null || can(regex("^[0-9]+-[0-9]+$", a.origin_port_range))
    ])
    error_message = "origin_port_range must look like 1000-2000."
  }

  validation {
    condition = alltrue([
      for a in values(var.applications) :
      length(coalesce(a.origin_direct, [])) > 0 || a.origin_dns != null
    ])
    error_message = "Each application must set origin_direct or origin_dns."
  }
}
