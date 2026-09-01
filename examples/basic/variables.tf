variable "account_id" {
  description = "Cloudflare account ID. Pools and monitors are account scoped."
  type        = string
  default     = "00000000000000000000000000000000"
}

variable "zone_id" {
  description = "Cloudflare zone ID. Load balancers are zone scoped."
  type        = string
  default     = "00000000000000000000000000000000"
}

variable "zone_name" {
  description = "DNS name of the zone, used to build the load balancer hostname."
  type        = string
  default     = "example.com"
}
