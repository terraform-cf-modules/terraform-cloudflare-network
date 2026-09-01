output "enabled" {
  description = "Whether this submodule created its resources."
  value       = var.enabled
}

output "applications" {
  description = "Full cloudflare_spectrum_application objects, keyed by the keys of var.applications."
  value       = merge(cloudflare_spectrum_application.this, cloudflare_spectrum_application.port_range)
}

output "application_ids" {
  description = "Spectrum application IDs, keyed by the keys of var.applications."
  value = {
    for k, v in merge(cloudflare_spectrum_application.this, cloudflare_spectrum_application.port_range) :
    k => v.id
  }
}
