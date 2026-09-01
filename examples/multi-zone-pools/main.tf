# Sharing one set of pools across several zones.
#
# This is the part of Cloudflare load balancing that catches people out. Pools
# and monitors are ACCOUNT scoped. Load balancers are ZONE scoped. So a single
# pool can back load balancers in as many zones as you like, and duplicating the
# pool per zone means duplicating the origin health checking that goes with it,
# which costs money and gives you two independent views of the same origins.
#
# The root module composes monitors, pools and load balancers together, which
# is what you want for one zone. For several zones, drive the submodules
# directly: build the monitors and pools once, then one load-balancer module per
# zone, all pointing at the same pool IDs.

provider "cloudflare" {
  # Reads CLOUDFLARE_API_TOKEN from the environment.
}

# Account scoped, built once.

module "monitor" {
  source = "../../modules/monitor"

  enabled    = true
  account_id = var.account_id

  monitors = {
    http = {
      type           = "http"
      description    = "Shared origin health check"
      path           = "/healthz"
      expected_codes = "2xx"
      interval       = 60
      timeout        = 5
      retries        = 2
    }
  }
}

module "pool" {
  source = "../../modules/pool"

  enabled    = true
  account_id = var.account_id

  pools = {
    europe = {
      description     = "European origins, shared by every zone"
      monitor         = module.monitor.monitor_ids["http"]
      minimum_origins = 1
      latitude        = 52.37
      longitude       = 4.89

      origins = {
        ams_1 = { address = "192.0.2.10", port = 443 }
        ams_2 = { address = "192.0.2.11", port = 443 }
      }
    }

    north_america = {
      description     = "North American origins, shared by every zone"
      monitor         = module.monitor.monitor_ids["http"]
      minimum_origins = 1
      latitude        = 37.77
      longitude       = -122.42

      origins = {
        sfo_1 = { address = "192.0.2.20", port = 443 }
      }
    }
  }
}

# Zone scoped, one module instance per zone, both pointing at the same pools.

module "primary_zone_load_balancer" {
  source = "../../modules/load-balancer"

  enabled = true
  zone_id = var.primary_zone_id

  load_balancers = {
    "www.${var.primary_zone_name}" = {
      description   = "Primary brand"
      default_pools = [module.pool.pool_ids["europe"], module.pool.pool_ids["north_america"]]
      fallback_pool = module.pool.pool_ids["north_america"]
      proxied       = true

      steering_policy = "proximity"

      adaptive_routing = {
        failover_across_pools = true
      }
    }
  }
}

module "secondary_zone_load_balancer" {
  source = "../../modules/load-balancer"

  enabled = true
  zone_id = var.secondary_zone_id

  load_balancers = {
    "www.${var.secondary_zone_name}" = {
      description = "Secondary brand, same origins, different steering"

      # Deliberately reversed: this brand prefers the North American origins.
      default_pools = [module.pool.pool_ids["north_america"], module.pool.pool_ids["europe"]]
      fallback_pool = module.pool.pool_ids["europe"]
      proxied       = true

      steering_policy = "off"
    }
  }
}
