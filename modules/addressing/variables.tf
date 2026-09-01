variable "enabled" {
  description = "Whether to create the resources managed by this submodule."
  type        = bool
  default     = true
}

variable "account_id" {
  description = "Cloudflare account ID that owns the prefixes and address maps."
  type        = string
  default     = null

  validation {
    condition     = var.account_id == null || can(regex("^[0-9a-f]{32}$", var.account_id))
    error_message = "account_id must be a 32 character lowercase hexadecimal Cloudflare account ID."
  }
}

variable "byo_ip_prefixes" {
  description = <<-EOT
    Bring Your Own IP prefixes to onboard, keyed by a stable identifier. Cloudflare will advertise the prefix under
    the given ASN once it has approved ownership, which is a manual review outside Terraform. Creating the resource
    only registers the prefix.
  EOT

  type = map(object({
    cidr                  = string
    asn                   = number
    description           = optional(string)
    delegate_loa_creation = optional(bool)
    loa_document_id       = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for p in values(var.byo_ip_prefixes) :
      can(cidrhost(p.cidr, 0))
    ])
    error_message = "Each byo_ip_prefixes cidr must be valid CIDR notation, for example 203.0.113.0/24."
  }

  validation {
    condition = alltrue([
      for p in values(var.byo_ip_prefixes) :
      p.asn > 0 && p.asn <= 4294967295
    ])
    error_message = "Each byo_ip_prefixes asn must be a valid 32 bit autonomous system number."
  }
}

variable "address_maps" {
  description = <<-EOT
    Address maps to create, keyed by a stable identifier. An address map pins a set of account owned IPs to
    specific zones or to the whole account, so Cloudflare DNS answers with those addresses instead of shared
    anycast space. A map only takes effect once enabled is true.
  EOT

  type = map(object({
    description = optional(string)
    enabled     = optional(bool, false)
    default_sni = optional(string)
    ips         = optional(list(string))
    memberships = optional(map(object({
      identifier = string
      kind       = string
    })), {})
  }))
  default = {}

  validation {
    condition = alltrue(flatten([
      for m in values(var.address_maps) : [
        for member in values(m.memberships) :
        contains(["zone", "account"], member.kind)
      ]
    ]))
    error_message = "Each address map membership kind must be zone or account."
  }

  validation {
    condition = alltrue(flatten([
      for m in values(var.address_maps) : [
        for member in values(m.memberships) :
        can(regex("^[0-9a-f]{32}$", member.identifier))
      ]
    ]))
    error_message = "Each address map membership identifier must be a 32 character lowercase hexadecimal zone or account ID."
  }
}
