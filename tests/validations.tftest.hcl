# Input validation. Plan only, no credentials.
#
# One case per validation block. Each run block feeds a deliberately wrong value
# and names the variable that must reject it.

mock_provider "cloudflare" {
  override_during = plan
}

variables {
  account_id = "00000000000000000000000000000000"
  zone_id    = "00000000000000000000000000000000"
}

# -----------------------------------------------------------------------------
# Scope anchors
# -----------------------------------------------------------------------------

run "rejects_malformed_account_id" {
  command = plan

  variables {
    account_id = "not-a-valid-account-id"
  }

  expect_failures = [var.account_id]
}

run "rejects_malformed_zone_id" {
  command = plan

  variables {
    zone_id = "TOO-SHORT"
  }

  expect_failures = [var.zone_id]
}

# -----------------------------------------------------------------------------
# Root module
# -----------------------------------------------------------------------------

run "rejects_unknown_monitor_type" {
  command = plan

  variables {
    monitors = {
      bad = { type = "gopher" }
    }
  }

  expect_failures = [var.monitors]
}

run "rejects_pool_with_no_origins" {
  command = plan

  variables {
    pools = {
      empty = { origins = {} }
    }
  }

  expect_failures = [var.pools]
}

run "rejects_pool_with_both_monitor_and_monitor_group" {
  command = plan

  variables {
    pools = {
      conflicted = {
        monitor       = "http"
        monitor_group = "combined"
        origins = {
          a = { address = "192.0.2.10" }
        }
      }
    }
  }

  expect_failures = [var.pools]
}

run "rejects_load_balancer_with_no_default_pools" {
  command = plan

  variables {
    load_balancers = {
      "www.example.com" = {
        default_pools = []
        fallback_pool = "primary"
      }
    }
  }

  expect_failures = [var.load_balancers]
}

run "rejects_unknown_steering_policy" {
  command = plan

  variables {
    load_balancers = {
      "www.example.com" = {
        default_pools   = ["primary"]
        fallback_pool   = "primary"
        steering_policy = "round_robin"
      }
    }
  }

  expect_failures = [var.load_balancers]
}

run "rejects_unknown_session_affinity" {
  command = plan

  variables {
    load_balancers = {
      "www.example.com" = {
        default_pools    = ["primary"]
        fallback_pool    = "primary"
        session_affinity = "sticky"
      }
    }
  }

  expect_failures = [var.load_balancers]
}

run "rejects_geo_steering_with_no_geo_maps" {
  command = plan

  variables {
    load_balancers = {
      "www.example.com" = {
        default_pools   = ["primary"]
        fallback_pool   = "primary"
        steering_policy = "geo"
      }
    }
  }

  expect_failures = [var.load_balancers]
}

# -----------------------------------------------------------------------------
# modules/monitor
# -----------------------------------------------------------------------------

run "monitor_rejects_out_of_range_port" {
  command = plan

  module {
    source = "./modules/monitor"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    monitors = {
      bad = { type = "tcp", port = 70000 }
    }
  }

  expect_failures = [var.monitors]
}

run "monitor_rejects_tcp_without_port" {
  command = plan

  module {
    source = "./modules/monitor"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    monitors = {
      bad = { type = "tcp" }
    }
  }

  expect_failures = [var.monitors]
}

run "monitor_group_rejects_member_without_a_reference" {
  command = plan

  module {
    source = "./modules/monitor"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    monitor_groups = {
      bad = {
        description = "Member names neither a key nor an ID"
        members = {
          orphan = {}
        }
      }
    }
  }

  expect_failures = [var.monitor_groups]
}

run "monitor_group_rejects_unknown_monitor_key" {
  command = plan

  module {
    source = "./modules/monitor"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    monitor_groups = {
      bad = {
        description = "Member points at a monitor that was never declared"
        members = {
          ghost = { monitor_key = "does_not_exist" }
        }
      }
    }
  }

  expect_failures = [var.monitor_groups]
}

run "healthcheck_rejects_unknown_type" {
  command = plan

  module {
    source = "./modules/monitor"
  }

  variables {
    zone_id = "00000000000000000000000000000000"
    healthchecks = {
      bad = { address = "192.0.2.10", type = "UDP" }
    }
  }

  expect_failures = [var.healthchecks]
}

run "healthcheck_rejects_invalid_http_method" {
  command = plan

  module {
    source = "./modules/monitor"
  }

  variables {
    zone_id = "00000000000000000000000000000000"
    healthchecks = {
      bad = {
        address     = "192.0.2.10"
        http_config = { method = "POST" }
      }
    }
  }

  expect_failures = [var.healthchecks]
}

# -----------------------------------------------------------------------------
# modules/pool
# -----------------------------------------------------------------------------

run "pool_rejects_invalid_name" {
  command = plan

  module {
    source = "./modules/pool"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    pools = {
      "not a valid pool name" = {
        origins = {
          a = { address = "192.0.2.10" }
        }
      }
    }
  }

  expect_failures = [var.pools]
}

run "pool_rejects_unknown_origin_steering_policy" {
  command = plan

  module {
    source = "./modules/pool"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    pools = {
      bad = {
        origins         = { a = { address = "192.0.2.10" } }
        origin_steering = { policy = "round_robin" }
      }
    }
  }

  expect_failures = [var.pools]
}

run "pool_rejects_out_of_range_load_shedding" {
  command = plan

  module {
    source = "./modules/pool"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    pools = {
      bad = {
        origins       = { a = { address = "192.0.2.10" } }
        load_shedding = { default_percent = 150 }
      }
    }
  }

  expect_failures = [var.pools]
}

run "pool_rejects_arbitrary_health_sources" {
  command = plan

  module {
    source = "./modules/pool"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    pools = {
      bad = {
        origins        = { a = { address = "192.0.2.10" } }
        check_regions  = ["WEU"]
        health_sources = ["local"]
      }
    }
  }

  expect_failures = [var.pools]
}

run "pool_rejects_regional_health_without_check_regions" {
  command = plan

  module {
    source = "./modules/pool"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    pools = {
      bad = {
        origins        = { a = { address = "192.0.2.10" } }
        health_sources = ["regional", "global"]
      }
    }
  }

  expect_failures = [var.pools]
}

run "pool_rejects_latitude_without_longitude" {
  command = plan

  module {
    source = "./modules/pool"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    pools = {
      bad = {
        origins  = { a = { address = "192.0.2.10" } }
        latitude = 52.37
      }
    }
  }

  expect_failures = [var.pools]
}

# -----------------------------------------------------------------------------
# modules/load-balancer
# -----------------------------------------------------------------------------

run "load_balancer_rejects_header_affinity_without_headers" {
  command = plan

  module {
    source = "./modules/load-balancer"
  }

  variables {
    zone_id = "00000000000000000000000000000000"
    load_balancers = {
      "www.example.com" = {
        default_pools    = ["11111111111111111111111111111111"]
        fallback_pool    = "11111111111111111111111111111111"
        session_affinity = "header"
      }
    }
  }

  expect_failures = [var.load_balancers]
}

run "load_balancer_rejects_unknown_samesite" {
  command = plan

  module {
    source = "./modules/load-balancer"
  }

  variables {
    zone_id = "00000000000000000000000000000000"
    load_balancers = {
      "www.example.com" = {
        default_pools               = ["11111111111111111111111111111111"]
        fallback_pool               = "11111111111111111111111111111111"
        session_affinity_attributes = { samesite = "lax" }
      }
    }
  }

  expect_failures = [var.load_balancers]
}

run "load_balancer_rejects_lowercase_country_codes" {
  command = plan

  module {
    source = "./modules/load-balancer"
  }

  variables {
    zone_id = "00000000000000000000000000000000"
    load_balancers = {
      "www.example.com" = {
        default_pools = ["11111111111111111111111111111111"]
        fallback_pool = "11111111111111111111111111111111"
        country_pools = { gb = ["11111111111111111111111111111111"] }
      }
    }
  }

  expect_failures = [var.load_balancers]
}

run "load_balancer_rejects_ttl_on_proxied_hostname" {
  command = plan

  module {
    source = "./modules/load-balancer"
  }

  variables {
    zone_id = "00000000000000000000000000000000"
    load_balancers = {
      "www.example.com" = {
        default_pools = ["11111111111111111111111111111111"]
        fallback_pool = "11111111111111111111111111111111"
        proxied       = true
        ttl           = 60
      }
    }
  }

  expect_failures = [var.load_balancers]
}

run "load_balancer_rejects_rule_with_both_response_and_overrides" {
  command = plan

  module {
    source = "./modules/load-balancer"
  }

  variables {
    zone_id = "00000000000000000000000000000000"
    load_balancers = {
      "www.example.com" = {
        default_pools = ["11111111111111111111111111111111"]
        fallback_pool = "11111111111111111111111111111111"
        rules = {
          conflicted = {
            condition      = "true"
            fixed_response = { status_code = 503 }
            overrides      = { steering_policy = "off" }
          }
        }
      }
    }
  }

  expect_failures = [var.load_balancers]
}

# -----------------------------------------------------------------------------
# modules/spectrum
# -----------------------------------------------------------------------------

run "spectrum_rejects_malformed_protocol" {
  command = plan

  module {
    source = "./modules/spectrum"
  }

  variables {
    zone_id = "00000000000000000000000000000000"
    applications = {
      bad = {
        protocol      = "22"
        dns           = { name = "ssh.example.com" }
        origin_direct = ["tcp://192.0.2.10:22"]
      }
    }
  }

  expect_failures = [var.applications]
}

run "spectrum_rejects_unknown_tls_mode" {
  command = plan

  module {
    source = "./modules/spectrum"
  }

  variables {
    zone_id = "00000000000000000000000000000000"
    applications = {
      bad = {
        protocol      = "tcp/22"
        dns           = { name = "ssh.example.com" }
        origin_direct = ["tcp://192.0.2.10:22"]
        tls           = "on"
      }
    }
  }

  expect_failures = [var.applications]
}

run "spectrum_rejects_both_origin_port_forms" {
  command = plan

  module {
    source = "./modules/spectrum"
  }

  variables {
    zone_id = "00000000000000000000000000000000"
    applications = {
      bad = {
        protocol          = "tcp/22"
        dns               = { name = "ssh.example.com" }
        origin_dns        = { name = "origin.example.net" }
        origin_port       = 22
        origin_port_range = "22-25"
      }
    }
  }

  expect_failures = [var.applications]
}

run "spectrum_rejects_application_with_no_origin" {
  command = plan

  module {
    source = "./modules/spectrum"
  }

  variables {
    zone_id = "00000000000000000000000000000000"
    applications = {
      bad = {
        protocol = "tcp/22"
        dns      = { name = "ssh.example.com" }
      }
    }
  }

  expect_failures = [var.applications]
}

# -----------------------------------------------------------------------------
# modules/addressing
# -----------------------------------------------------------------------------

run "addressing_rejects_malformed_cidr" {
  command = plan

  module {
    source = "./modules/addressing"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    byo_ip_prefixes = {
      bad = { cidr = "203.0.113.0", asn = 64512 }
    }
  }

  expect_failures = [var.byo_ip_prefixes]
}

run "addressing_rejects_unknown_membership_kind" {
  command = plan

  module {
    source = "./modules/addressing"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    address_maps = {
      bad = {
        memberships = {
          one = { identifier = "00000000000000000000000000000000", kind = "hostname" }
        }
      }
    }
  }

  expect_failures = [var.address_maps]
}

# -----------------------------------------------------------------------------
# modules/monitoring
# -----------------------------------------------------------------------------

run "monitoring_rejects_unknown_rule_type" {
  command = plan

  module {
    source = "./modules/monitoring"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    rules = {
      bad = { type = "anomaly", prefixes = ["203.0.113.0/24"] }
    }
  }

  expect_failures = [var.rules]
}

run "monitoring_rejects_unknown_duration" {
  command = plan

  module {
    source = "./modules/monitoring"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    rules = {
      bad = {
        type                = "threshold"
        prefixes            = ["203.0.113.0/24"]
        bandwidth_threshold = 1000
        duration            = "2m"
      }
    }
  }

  expect_failures = [var.rules]
}

run "monitoring_rejects_threshold_rule_without_a_threshold" {
  command = plan

  module {
    source = "./modules/monitoring"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    rules = {
      bad = { type = "threshold", prefixes = ["203.0.113.0/24"] }
    }
  }

  expect_failures = [var.rules]
}

run "monitoring_rejects_warp_device_without_slash_32" {
  command = plan

  module {
    source = "./modules/monitoring"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    configuration = {
      name = "example-account"
      warp_devices = {
        bad = {
          id        = "00000000-0000-0000-0000-000000000000"
          name      = "bad"
          router_ip = "203.0.113.0/24"
        }
      }
    }
  }

  expect_failures = [var.configuration]
}

# -----------------------------------------------------------------------------
# modules/magic-wan
# -----------------------------------------------------------------------------

run "magic_wan_rejects_overlong_gre_tunnel_name" {
  command = plan

  module {
    source = "./modules/magic-wan"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    gre_tunnels = {
      this-name-is-far-too-long-for-cloudflare = {
        cloudflare_gre_endpoint = "203.0.113.1"
        customer_gre_endpoint   = "198.51.100.1"
        interface_address       = "10.10.10.0/31"
      }
    }
  }

  expect_failures = [var.gre_tunnels]
}

run "magic_wan_rejects_non_slash_31_interface_address" {
  command = plan

  module {
    source = "./modules/magic-wan"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    gre_tunnels = {
      branch = {
        cloudflare_gre_endpoint = "203.0.113.1"
        customer_gre_endpoint   = "198.51.100.1"
        interface_address       = "10.10.10.0/30"
      }
    }
  }

  expect_failures = [var.gre_tunnels]
}

run "magic_wan_rejects_unknown_health_check_rate" {
  command = plan

  module {
    source = "./modules/magic-wan"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    ipsec_tunnels = {
      branch = {
        cloudflare_endpoint = "203.0.113.1"
        interface_address   = "10.10.10.0/31"
        health_check_rate   = "fastest"
      }
    }
  }

  expect_failures = [var.ipsec_tunnels]
}

run "magic_wan_rejects_malformed_static_route_prefix" {
  command = plan

  module {
    source = "./modules/magic-wan"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    static_routes = {
      bad = { prefix = "10.20.0.0", nexthop = "10.10.10.1", priority = 100 }
    }
  }

  expect_failures = [var.static_routes]
}

# -----------------------------------------------------------------------------
# modules/magic-transit
# -----------------------------------------------------------------------------

run "magic_transit_rejects_connector_without_a_device" {
  command = plan

  module {
    source = "./modules/magic-transit"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    connectors = {
      bad = { notes = "No serial number and no device ID" }
    }
  }

  expect_failures = [var.connectors]
}

run "magic_transit_rejects_secondary_connector_without_ha_mode" {
  command = plan

  module {
    source = "./modules/magic-transit"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    sites = {
      bad = {
        connector_id           = "11111111-1111-1111-1111-111111111111"
        secondary_connector_id = "22222222-2222-2222-2222-222222222222"
      }
    }
  }

  expect_failures = [var.sites]
}

run "magic_transit_rejects_lan_with_unknown_site_key" {
  command = plan

  module {
    source = "./modules/magic-transit"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    site_lans = {
      bad = { site_key = "does_not_exist" }
    }
  }

  expect_failures = [var.site_lans]
}

run "magic_transit_rejects_out_of_range_vlan_tag" {
  command = plan

  module {
    source = "./modules/magic-transit"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    site_wans = {
      bad = {
        site_id  = "11111111-1111-1111-1111-111111111111"
        physport = 1
        vlan_tag = 5000
      }
    }
  }

  expect_failures = [var.site_wans]
}

run "magic_transit_rejects_reserved_dhcp_option_code" {
  command = plan

  module {
    source = "./modules/magic-transit"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    site_lans = {
      bad = {
        site_id = "11111111-1111-1111-1111-111111111111"
        static_addressing = {
          address = "10.20.0.1/24"
          dhcp_server = {
            dhcp_options = {
              router = { code = 3, type = "ip", value = "10.20.0.1" }
            }
          }
        }
      }
    }
  }

  expect_failures = [var.site_lans]
}

run "magic_transit_rejects_acl_side_with_both_key_and_id" {
  command = plan

  module {
    source = "./modules/magic-transit"
  }

  variables {
    account_id = "00000000000000000000000000000000"
    site_acls = {
      bad = {
        site_id = "11111111-1111-1111-1111-111111111111"
        lan_1 = {
          lan_key = "branch_lan"
          lan_id  = "33333333-3333-3333-3333-333333333333"
        }
        lan_2 = {
          lan_id = "44444444-4444-4444-4444-444444444444"
        }
      }
    }
  }

  expect_failures = [var.site_acls]
}
