variable "account_id" {
  description = "Cloudflare account ID. Monitors and pools are account scoped, so both zones share them."
  type        = string
  default     = "00000000000000000000000000000000"
}

variable "primary_zone_id" {
  description = "Cloudflare zone ID for the primary brand."
  type        = string
  default     = "00000000000000000000000000000000"
}

variable "primary_zone_name" {
  description = "DNS name of the primary zone, used to build the load balancer hostname."
  type        = string
  default     = "example.com"
}

variable "secondary_zone_id" {
  description = "Cloudflare zone ID for the secondary brand."
  type        = string
  default     = "11111111111111111111111111111111"
}

variable "secondary_zone_name" {
  description = "DNS name of the secondary zone, used to build the load balancer hostname."
  type        = string
  default     = "example.net"
}
