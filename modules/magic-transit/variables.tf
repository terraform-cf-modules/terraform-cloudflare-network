variable "enabled" {
  description = "Whether to create the resources managed by this submodule."
  type        = bool
  default     = true
}

variable "account_id" {
  description = "Cloudflare account ID that owns the Magic Transit sites and connectors."
  type        = string
  default     = null

  validation {
    condition     = var.account_id == null || can(regex("^[0-9a-f]{32}$", var.account_id))
    error_message = "account_id must be a 32 character lowercase hexadecimal Cloudflare account ID."
  }
}

variable "connectors" {
  description = <<-EOT
    Magic Connectors to register, keyed by a stable identifier. A connector is the physical or virtual appliance
    that terminates a Magic Transit site. Identify the device by serial_number for hardware you already own, or
    set device_id when Cloudflare has already allocated one.

    Magic Transit is an enterprise product. Leave this map empty unless your account is onboarded.
  EOT

  type = map(object({
    device_serial_number            = optional(string)
    device_id                       = optional(string)
    device_provision_license        = optional(bool)
    activated                       = optional(bool)
    notes                           = optional(string)
    timezone                        = optional(string)
    interrupt_window_hour_of_day    = optional(number)
    interrupt_window_duration_hours = optional(number)
  }))
  default = {}

  validation {
    condition = alltrue([
      for c in values(var.connectors) :
      c.device_serial_number != null || c.device_id != null
    ])
    error_message = "Each connector must set device_serial_number or device_id."
  }

  validation {
    condition = alltrue([
      for c in values(var.connectors) :
      c.interrupt_window_hour_of_day == null || (c.interrupt_window_hour_of_day >= 0 && c.interrupt_window_hour_of_day <= 23)
    ])
    error_message = "interrupt_window_hour_of_day must be between 0 and 23."
  }
}

variable "sites" {
  description = <<-EOT
    Magic Transit sites, keyed by a stable identifier. The map key becomes the site name unless the object sets
    name explicitly. connector_key names a key in var.connectors; connector_id takes an existing connector ID.
    Set ha_mode to run two connectors at the same site.
  EOT

  type = map(object({
    name                    = optional(string)
    description             = optional(string)
    ha_mode                 = optional(bool)
    connector_key           = optional(string)
    connector_id            = optional(string)
    secondary_connector_key = optional(string)
    secondary_connector_id  = optional(string)
    location = optional(object({
      lat = optional(string)
      lon = optional(string)
    }))
  }))
  default = {}

  validation {
    condition = alltrue([
      for s in values(var.sites) :
      !(s.connector_key != null && s.connector_id != null)
    ])
    error_message = "Set at most one of connector_key and connector_id on each site."
  }

  validation {
    condition = alltrue([
      for s in values(var.sites) :
      !(s.secondary_connector_key != null && s.secondary_connector_id != null)
    ])
    error_message = "Set at most one of secondary_connector_key and secondary_connector_id on each site."
  }

  validation {
    condition = alltrue([
      for s in values(var.sites) :
      s.connector_key == null || contains(keys(var.connectors), s.connector_key)
    ])
    error_message = "Every site connector_key must name a key present in var.connectors."
  }

  validation {
    condition = alltrue([
      for s in values(var.sites) :
      s.secondary_connector_key == null || contains(keys(var.connectors), s.secondary_connector_key)
    ])
    error_message = "Every site secondary_connector_key must name a key present in var.connectors."
  }

  validation {
    condition = alltrue([
      for s in values(var.sites) :
      (s.secondary_connector_key == null && s.secondary_connector_id == null) || s.ha_mode == true
    ])
    error_message = "A secondary connector only applies when ha_mode is true."
  }
}

variable "site_lans" {
  description = <<-EOT
    LAN interfaces on Magic Transit sites, keyed by a stable identifier. Each LAN attaches to a site by site_key,
    naming a key in var.sites, or by site_id for a site managed elsewhere. static_addressing configures the
    Cloudflare side address and, optionally, DHCP relay or a DHCP server for the subnet.
  EOT

  type = map(object({
    site_key = optional(string)
    site_id  = optional(string)

    name           = optional(string)
    physport       = optional(number)
    vlan_tag       = optional(number)
    bond_id        = optional(number)
    ha_link        = optional(bool)
    is_breakout    = optional(bool)
    is_prioritized = optional(bool)

    nat_static_prefix = optional(string)

    routed_subnets = optional(map(object({
      prefix            = string
      next_hop          = string
      nat_static_prefix = optional(string)
    })), {})

    static_addressing = optional(object({
      address           = string
      secondary_address = optional(string)
      virtual_address   = optional(string)
      dhcp_relay = optional(object({
        server_addresses = optional(list(string))
      }))
      dhcp_server = optional(object({
        dhcp_pool_start = optional(string)
        dhcp_pool_end   = optional(string)
        dns_server      = optional(string)
        dns_servers     = optional(list(string))
        reservations    = optional(map(string))
        dhcp_options = optional(map(object({
          code  = number
          type  = string
          value = string
        })), {})
      }))
    }))
  }))
  default = {}

  validation {
    condition = alltrue([
      for l in values(var.site_lans) :
      (l.site_key != null) != (l.site_id != null)
    ])
    error_message = "Each LAN must set exactly one of site_key and site_id."
  }

  validation {
    condition = alltrue([
      for l in values(var.site_lans) :
      l.site_key == null || contains(keys(var.sites), l.site_key)
    ])
    error_message = "Every LAN site_key must name a key present in var.sites."
  }

  validation {
    condition = alltrue([
      for l in values(var.site_lans) :
      l.vlan_tag == null || (l.vlan_tag >= 0 && l.vlan_tag <= 4094)
    ])
    error_message = "vlan_tag must be between 0 and 4094. Zero means untagged."
  }

  validation {
    condition = alltrue(flatten([
      for l in values(var.site_lans) : [
        for option in values(try(l.static_addressing.dhcp_server.dhcp_options, {})) :
        contains(["text", "hex", "ip", "byte", "short", "integer"], option.type)
      ]
    ]))
    error_message = "Each DHCP option type must be one of text, hex, ip, byte, short, integer."
  }

  validation {
    condition = alltrue(flatten([
      for l in values(var.site_lans) : [
        for option in values(try(l.static_addressing.dhcp_server.dhcp_options, {})) :
        option.code >= 1 && option.code <= 254 && !contains([3, 6, 51], option.code)
      ]
    ]))
    error_message = "DHCP option codes must be between 1 and 254 and must not be 3, 6 or 51, which conflict with connector managed configuration."
  }
}

variable "site_wans" {
  description = <<-EOT
    WAN interfaces on Magic Transit sites, keyed by a stable identifier. Each WAN attaches to a site by site_key,
    naming a key in var.sites, or by site_id. physport is the physical port number on the connector.
  EOT

  type = map(object({
    site_key = optional(string)
    site_id  = optional(string)

    physport = number
    name     = optional(string)
    priority = optional(number)
    vlan_tag = optional(number)

    static_addressing = optional(object({
      address           = string
      gateway_address   = string
      secondary_address = optional(string)
    }))
  }))
  default = {}

  validation {
    condition = alltrue([
      for w in values(var.site_wans) :
      (w.site_key != null) != (w.site_id != null)
    ])
    error_message = "Each WAN must set exactly one of site_key and site_id."
  }

  validation {
    condition = alltrue([
      for w in values(var.site_wans) :
      w.site_key == null || contains(keys(var.sites), w.site_key)
    ])
    error_message = "Every WAN site_key must name a key present in var.sites."
  }

  validation {
    condition = alltrue([
      for w in values(var.site_wans) :
      w.vlan_tag == null || (w.vlan_tag >= 0 && w.vlan_tag <= 4094)
    ])
    error_message = "vlan_tag must be between 0 and 4094. Zero means untagged."
  }
}

variable "site_acls" {
  description = <<-EOT
    ACL policies between two LANs on a Magic Transit site, keyed by a stable identifier. The map key becomes the
    policy name unless the object sets name explicitly. Each side references a LAN either by lan_key, naming a key
    in var.site_lans, or by lan_id.
  EOT

  type = map(object({
    site_key = optional(string)
    site_id  = optional(string)

    name        = optional(string)
    description = optional(string)

    lan_1 = object({
      lan_key     = optional(string)
      lan_id      = optional(string)
      lan_name    = optional(string)
      ports       = optional(list(number))
      port_ranges = optional(list(string))
      subnets     = optional(list(string))
    })

    lan_2 = object({
      lan_key     = optional(string)
      lan_id      = optional(string)
      lan_name    = optional(string)
      ports       = optional(list(number))
      port_ranges = optional(list(string))
      subnets     = optional(list(string))
    })

    protocols       = optional(list(string))
    forward_locally = optional(bool)
    unidirectional  = optional(bool)
  }))
  default = {}

  validation {
    condition = alltrue([
      for a in values(var.site_acls) :
      (a.site_key != null) != (a.site_id != null)
    ])
    error_message = "Each ACL must set exactly one of site_key and site_id."
  }

  validation {
    condition = alltrue([
      for a in values(var.site_acls) :
      a.site_key == null || contains(keys(var.sites), a.site_key)
    ])
    error_message = "Every ACL site_key must name a key present in var.sites."
  }

  validation {
    condition = alltrue(flatten([
      for a in values(var.site_acls) : [
        for lan in [a.lan_1, a.lan_2] :
        (lan.lan_key != null) != (lan.lan_id != null)
      ]
    ]))
    error_message = "Each ACL side must set exactly one of lan_key and lan_id."
  }

  validation {
    condition = alltrue(flatten([
      for a in values(var.site_acls) : [
        for lan in [a.lan_1, a.lan_2] :
        lan.lan_key == null || contains(keys(var.site_lans), lan.lan_key)
      ]
    ]))
    error_message = "Every ACL lan_key must name a key present in var.site_lans."
  }

  validation {
    condition = alltrue([
      for a in values(var.site_acls) :
      alltrue([for p in coalesce(a.protocols, []) : contains(["tcp", "udp", "icmp"], lower(p))])
    ])
    error_message = "ACL protocols must be drawn from tcp, udp, icmp."
  }
}
