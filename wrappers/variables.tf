variable "defaults" {
  description = "Values applied to every item unless the item overrides them."
  type        = any
  default     = {}
}

variable "items" {
  description = "Map of module instances to create, keyed by a stable identifier."
  type        = any
  default     = {}
}
