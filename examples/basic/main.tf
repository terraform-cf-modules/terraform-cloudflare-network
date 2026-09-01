# Minimum viable configuration for the Cloudflare Network module.
#
# One HTTP monitor, one pool with two origins, and a proxied load balancer that
# fails over between them. The pool references the monitor by its map key and
# the load balancer references the pool by its map key; the module resolves both
# to Cloudflare IDs.

provider "cloudflare" {
  # Reads CLOUDFLARE_API_TOKEN from the environment.
}

module "this" {
  source = "../../"

  enabled    = true
  account_id = var.account_id
  zone_id    = var.zone_id

  monitors = {
    http = {
      type           = "http"
      description    = "Root path health check"
      path           = "/"
      expected_codes = "200"
      interval       = 60
      timeout        = 5
      retries        = 2
    }
  }

  pools = {
    primary = {
      description = "Primary origin pool"
      monitor     = "http"

      origins = {
        origin_a = {
          address = "192.0.2.10"
          weight  = 1
        }
        origin_b = {
          address = "192.0.2.11"
          weight  = 1
        }
      }
    }
  }

  load_balancers = {
    "www.${var.zone_name}" = {
      description   = "Public entry point"
      default_pools = ["primary"]
      fallback_pool = "primary"
      proxied       = true
    }
  }
}
