# Every optional feature of the Cloudflare Network module turned on.
#
# The root module builds the full load balancing stack: monitors, a monitor
# group, standalone health checks, three pools with origin steering and load
# shedding, and two load balancers, one of them using geo steering with region,
# country and PoP maps plus a BETA rule.
#
# The remaining building blocks are instantiated directly from modules/.
# Magic WAN and Magic Transit are enterprise only, so they are guarded behind
# variables that default to false. Turning them on here would suggest they work
# on any account, which they do not.

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
      type             = "http"
      description      = "Root path health check"
      method           = "GET"
      path             = "/healthz"
      expected_codes   = "2xx"
      expected_body    = "ok"
      interval         = 60
      timeout          = 5
      retries          = 2
      consecutive_up   = 2
      consecutive_down = 3
      follow_redirects = true
      allow_insecure   = false
      probe_zone       = var.zone_name
      header = {
        Host = [var.zone_name]
      }
    }

    tcp = {
      type        = "tcp"
      description = "Raw TCP reachability"
      method      = "connection_established"
      port        = 8080
      interval    = 60
      timeout     = 5
      retries     = 2
    }
  }

  monitor_groups = {
    combined = {
      description = "HTTP and TCP checks judged together"

      members = {
        http = {
          monitor_key     = "http"
          must_be_healthy = true
        }
        tcp = {
          monitor_key     = "tcp"
          monitoring_only = true
          must_be_healthy = false
        }
      }
    }
  }

  healthchecks = {
    origin-a = {
      address               = "192.0.2.10"
      type                  = "HTTPS"
      description           = "Standalone check on origin A"
      check_regions         = ["WEU", "ENAM"]
      consecutive_fails     = 2
      consecutive_successes = 2
      interval              = 60
      retries               = 2
      timeout               = 5
      suspended             = false

      http_config = {
        method           = "GET"
        path             = "/healthz"
        port             = 443
        expected_codes   = ["200", "204"]
        expected_body    = "ok"
        follow_redirects = true
        allow_insecure   = false
        header = {
          Host = [var.zone_name]
        }
      }
    }

    origin-b-tcp = {
      address     = "192.0.2.11"
      type        = "TCP"
      description = "Standalone TCP check on origin B"
      interval    = 60

      tcp_config = {
        method = "connection_established"
        port   = 8080
      }
    }
  }

  pools = {
    europe = {
      description        = "European origins"
      monitor_group      = "combined"
      minimum_origins    = 1
      check_regions      = ["WEU", "EEU"]
      health_sources     = ["regional", "global"]
      latitude           = 52.37
      longitude          = 4.89
      notification_email = "noc@example.com"

      origins = {
        ams_1 = {
          address     = "192.0.2.10"
          port        = 443
          weight      = 0.6
          host_header = var.zone_name
        }
        ams_2 = {
          address = "192.0.2.11"
          port    = 443
          weight  = 0.4
        }
      }

      origin_steering = {
        policy = "least_outstanding_requests"
      }

      load_shedding = {
        default_percent = 10
        default_policy  = "random"
        session_percent = 5
        session_policy  = "hash"
      }

      notification_filter = {
        pool = {
          healthy = false
        }
        origin = {
          disable = true
        }
      }
    }

    north_america = {
      description     = "North American origins"
      monitor         = "http"
      minimum_origins = 1
      latitude        = 37.77
      longitude       = -122.42

      origins = {
        sfo_1 = {
          address       = "origin-sfo.example.net"
          port          = 443
          flatten_cname = true
        }
      }
    }

    maintenance = {
      description = "Static maintenance page origin, kept out of rotation"
      enabled     = false

      origins = {
        holding = {
          address = "192.0.2.99"
        }
      }
    }
  }

  load_balancers = {
    "www.${var.zone_name}" = {
      description   = "Geo steered public entry point"
      default_pools = ["europe", "north_america"]
      fallback_pool = "north_america"
      proxied       = true

      steering_policy      = "geo"
      session_affinity     = "cookie"
      session_affinity_ttl = 3600

      region_pools = {
        WEU  = ["europe"]
        EEU  = ["europe"]
        ENAM = ["north_america"]
        WNAM = ["north_america"]
      }

      country_pools = {
        GB = ["europe", "north_america"]
        US = ["north_america"]
      }

      pop_pools = {
        LHR = ["europe"]
        SFO = ["north_america"]
      }

      adaptive_routing = {
        failover_across_pools = true
      }

      location_strategy = {
        mode       = "resolver_ip"
        prefer_ecs = "proximity"
      }

      random_steering = {
        default_weight = 0.5
        pool_weights = {
          europe        = 0.7
          north_america = 0.3
        }
      }

      session_affinity_attributes = {
        drain_duration         = 100
        samesite               = "Lax"
        secure                 = "Auto"
        zero_downtime_failover = "sticky"
      }

      # BETA in the Cloudflare API. Rules are keyed so one can be added or
      # removed without reordering the rest; priority decides evaluation order.
      rules = {
        maintenance_window = {
          condition  = "http.request.uri.path contains \"/maintenance\""
          priority   = 10
          terminates = true

          fixed_response = {
            status_code  = 503
            content_type = "text/plain"
            message_body = "Scheduled maintenance in progress."
          }
        }

        api_traffic = {
          condition = "http.request.uri.path starts_with \"/api\""
          priority  = 20

          overrides = {
            default_pools    = ["north_america"]
            fallback_pool    = "europe"
            steering_policy  = "least_connections"
            session_affinity = "none"

            adaptive_routing = {
              failover_across_pools = false
            }
          }
        }
      }
    }

    "api.${var.zone_name}" = {
      description   = "Unproxied latency steered endpoint"
      default_pools = ["north_america", "europe"]
      fallback_pool = "europe"
      proxied       = false
      ttl           = 60

      steering_policy  = "dynamic_latency"
      session_affinity = "none"
    }
  }
}

# -----------------------------------------------------------------------------
# Spectrum: proxy non HTTP traffic through Cloudflare.
# -----------------------------------------------------------------------------

module "spectrum" {
  source = "../../modules/spectrum"

  enabled = true
  zone_id = var.zone_id

  applications = {
    ssh = {
      protocol = "tcp/22"

      dns = {
        type = "CNAME"
        name = "ssh.${var.zone_name}"
      }

      origin_direct      = ["tcp://192.0.2.10:22"]
      argo_smart_routing = true
      ip_firewall        = true
      proxy_protocol     = "v2"
      tls                = "off"
      traffic_type       = "direct"

      edge_ips = {
        type         = "dynamic"
        connectivity = "all"
      }
    }

    minecraft = {
      protocol = "tcp/25565-25575"

      dns = {
        type = "CNAME"
        name = "game.${var.zone_name}"
      }

      origin_dns = {
        name = "origin.example.net"
        type = "A"
        ttl  = 600
      }

      origin_port_range = "25565-25575"
      tls               = "off"
      traffic_type      = "direct"
    }
  }
}

# -----------------------------------------------------------------------------
# Addressing: BYOIP prefixes and address maps.
# -----------------------------------------------------------------------------

module "addressing" {
  source = "../../modules/addressing"

  enabled    = var.enable_addressing
  account_id = var.account_id

  byo_ip_prefixes = {
    primary = {
      cidr                  = "203.0.113.0/24"
      asn                   = 64512
      description           = "Customer owned prefix"
      delegate_loa_creation = true
    }
  }

  address_maps = {
    dedicated = {
      description = "Dedicated addresses for the apex zone"
      enabled     = true
      default_sni = var.zone_name
      ips         = ["203.0.113.10", "203.0.113.11"]

      memberships = {
        zone = {
          identifier = var.zone_id
          kind       = "zone"
        }
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Magic Network Monitoring: flow analysis and alerting.
# -----------------------------------------------------------------------------

module "monitoring" {
  source = "../../modules/monitoring"

  enabled    = var.enable_magic_network_monitoring
  account_id = var.account_id

  configuration = {
    name             = "example-account"
    default_sampling = 10000
    router_ips       = ["203.0.113.1"]

    warp_devices = {
      branch_office = {
        id        = "00000000-0000-0000-0000-000000000000"
        name      = "branch-office"
        router_ip = "203.0.113.2/32"
      }
    }
  }

  rules = {
    inbound_flood = {
      type                    = "threshold"
      prefixes                = ["203.0.113.0/24"]
      bandwidth_threshold     = 1000000000
      packet_threshold        = 100000
      duration                = "5m"
      automatic_advertisement = false
    }

    baseline_deviation = {
      type               = "zscore"
      prefixes           = ["203.0.113.0/24"]
      duration           = "10m"
      zscore_sensitivity = "medium"
      zscore_target      = "bits"
    }
  }
}

# -----------------------------------------------------------------------------
# Magic WAN and Magic Transit: enterprise only, off by default.
#
# These modules are wired up so the configuration is there to copy, but both
# guards default to false. Cloudflare has to onboard an account before either
# product exists, and a working plan here would wrongly imply otherwise.
# -----------------------------------------------------------------------------

module "magic_wan" {
  source = "../../modules/magic-wan"

  enabled    = var.enable_magic_wan
  account_id = var.account_id

  gre_tunnels = {
    branch-gre = {
      cloudflare_gre_endpoint = "203.0.113.1"
      customer_gre_endpoint   = "198.51.100.1"
      interface_address       = "10.10.10.0/31"
      description             = "Branch office GRE tunnel"
      mtu                     = 1476
      ttl                     = 64

      health_check_enabled   = true
      health_check_direction = "bidirectional"
      health_check_rate      = "mid"
      health_check_type      = "reply"
    }
  }

  ipsec_tunnels = {
    branch-ipsec = {
      cloudflare_endpoint = "203.0.113.2"
      customer_endpoint   = "198.51.100.2"
      interface_address   = "10.10.10.2/31"
      description         = "Branch office IPsec tunnel"
      replay_protection   = true

      health_check_enabled   = true
      health_check_direction = "unidirectional"
      health_check_rate      = "low"
      health_check_type      = "request"
    }
  }

  # Left empty on purpose. Supplying a key here writes it to Terraform state;
  # omitting a tunnel lets Cloudflare generate one instead.
  ipsec_tunnel_psks = {}

  static_routes = {
    branch_lan = {
      prefix      = "10.20.0.0/16"
      nexthop     = "10.10.10.1"
      priority    = 100
      weight      = 10
      description = "Branch office LAN behind the GRE tunnel"

      scope = {
        colo_regions = ["WEU"]
      }
    }
  }
}

module "magic_transit" {
  source = "../../modules/magic-transit"

  enabled    = var.enable_magic_transit
  account_id = var.account_id

  connectors = {
    branch = {
      device_serial_number     = "SERIAL0000000000"
      device_provision_license = true
      activated                = true
      notes                    = "Branch office connector"
      timezone                 = "Europe/London"

      interrupt_window_hour_of_day    = 2
      interrupt_window_duration_hours = 4
    }
  }

  sites = {
    branch = {
      description   = "Branch office"
      connector_key = "branch"

      location = {
        lat = "51.51"
        lon = "-0.13"
      }
    }
  }

  site_wans = {
    branch_wan = {
      site_key = "branch"
      physport = 1
      name     = "wan1"
      priority = 100

      static_addressing = {
        address         = "198.51.100.10/30"
        gateway_address = "198.51.100.9"
      }
    }
  }

  site_lans = {
    branch_lan = {
      site_key    = "branch"
      physport    = 2
      name        = "lan1"
      vlan_tag    = 0
      is_breakout = false

      static_addressing = {
        address = "10.20.0.1/24"

        dhcp_server = {
          dhcp_pool_start = "10.20.0.100"
          dhcp_pool_end   = "10.20.0.200"
          dns_servers     = ["1.1.1.1", "1.0.0.1"]

          dhcp_options = {
            domain_name = {
              code  = 15
              type  = "text"
              value = "branch.example.com"
            }
          }
        }
      }

      routed_subnets = {
        lab = {
          prefix   = "10.20.1.0/24"
          next_hop = "10.20.0.2"
        }
      }
    }

    guest_lan = {
      site_key = "branch"
      physport = 3
      name     = "guest"
      vlan_tag = 100

      static_addressing = {
        address = "10.30.0.1/24"

        dhcp_relay = {
          server_addresses = ["10.20.0.53"]
        }
      }
    }
  }

  site_acls = {
    lan_to_guest = {
      site_key    = "branch"
      description = "Allow the office LAN to reach guest services"
      protocols   = ["tcp", "udp"]

      lan_1 = {
        lan_key = "branch_lan"
        ports   = [53, 443]
      }

      lan_2 = {
        lan_key     = "guest_lan"
        port_ranges = ["8000-8100"]
      }

      unidirectional  = true
      forward_locally = false
    }
  }
}
