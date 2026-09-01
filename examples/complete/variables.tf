variable "account_id" {
  description = "Cloudflare account ID. Pools, monitors, addressing, Magic WAN and Magic Transit are account scoped."
  type        = string
  default     = "00000000000000000000000000000000"
}

variable "zone_id" {
  description = "Cloudflare zone ID. Load balancers, health checks and Spectrum applications are zone scoped."
  type        = string
  default     = "00000000000000000000000000000000"
}

variable "zone_name" {
  description = "DNS name of the zone, used to build hostnames."
  type        = string
  default     = "example.com"
}

variable "enable_addressing" {
  description = "Create the BYOIP prefix and address map. BYOIP needs Cloudflare to approve prefix ownership out of band, so this is off by default."
  type        = bool
  default     = false
}

variable "enable_magic_network_monitoring" {
  description = "Create the Magic Network Monitoring configuration and rules. Needs routers exporting flow data to Cloudflare."
  type        = bool
  default     = false
}

variable "enable_magic_wan" {
  description = "Create the Magic WAN tunnels and static routes. Magic WAN is an enterprise product that Cloudflare must onboard the account for, so this is off by default."
  type        = bool
  default     = false
}

variable "enable_magic_transit" {
  description = "Create the Magic Transit connectors, sites, LANs, WANs and ACLs. Magic Transit is an enterprise product that Cloudflare must onboard the account for, so this is off by default."
  type        = bool
  default     = false
}
