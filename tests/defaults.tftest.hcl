# Plan only. Runs on every pull request, including forks, with no credentials.

mock_provider "cloudflare" {
  override_during = plan
}

variables {
  account_id = "00000000000000000000000000000000"
  zone_id    = "00000000000000000000000000000000"
}

run "creates_nothing_when_disabled" {
  command = plan

  variables {
    enabled = false

    monitors = {
      http = { type = "http", path = "/" }
    }

    pools = {
      primary = {
        monitor = "http"
        origins = {
          a = { address = "192.0.2.10" }
        }
      }
    }

    load_balancers = {
      "www.example.com" = {
        default_pools = ["primary"]
        fallback_pool = "primary"
      }
    }
  }

  assert {
    condition     = output.enabled == false
    error_message = "Module reported enabled while var.enabled was false."
  }

  assert {
    condition     = length(output.monitor_ids) == 0
    error_message = "Disabled module still planned monitors."
  }

  assert {
    condition     = length(output.pool_ids) == 0
    error_message = "Disabled module still planned pools."
  }

  assert {
    condition     = length(output.load_balancer_ids) == 0
    error_message = "Disabled module still planned load balancers."
  }
}

run "enabled_by_default" {
  command = plan

  assert {
    condition     = output.enabled == true
    error_message = "Module should be enabled by default."
  }
}

run "creates_nothing_with_empty_inputs" {
  command = plan

  assert {
    condition     = length(output.pool_ids) == 0 && length(output.load_balancer_ids) == 0
    error_message = "Module created resources with no collections configured."
  }
}

run "wires_monitor_pool_and_load_balancer" {
  command = plan

  variables {
    monitors = {
      http = {
        type           = "http"
        path           = "/healthz"
        expected_codes = "2xx"
        interval       = 60
      }
      tcp = {
        type = "tcp"
        port = 8080
      }
    }

    monitor_groups = {
      combined = {
        description = "HTTP and TCP judged together"
        members = {
          http = { monitor_key = "http" }
          tcp  = { monitor_key = "tcp", monitoring_only = true }
        }
      }
    }

    healthchecks = {
      origin-a = {
        address = "192.0.2.10"
        type    = "HTTPS"
        http_config = {
          method = "GET"
          path   = "/healthz"
        }
      }
    }

    pools = {
      europe = {
        monitor_group   = "combined"
        minimum_origins = 1
        check_regions   = ["WEU"]
        health_sources  = ["regional", "global"]
        latitude        = 52.37
        longitude       = 4.89

        origins = {
          ams_1 = { address = "192.0.2.10", port = 443, weight = 0.6, host_header = "example.com" }
          ams_2 = { address = "192.0.2.11", port = 443, weight = 0.4 }
        }

        origin_steering = { policy = "least_outstanding_requests" }
        load_shedding = {
          default_percent = 10
          default_policy  = "random"
          session_policy  = "hash"
        }
        notification_filter = {
          pool = { healthy = false }
        }
      }

      north_america = {
        monitor = "http"
        origins = {
          sfo_1 = { address = "origin.example.net" }
        }
      }
    }

    load_balancers = {
      "www.example.com" = {
        default_pools   = ["europe", "north_america"]
        fallback_pool   = "north_america"
        proxied         = true
        steering_policy = "geo"

        region_pools  = { WEU = ["europe"], ENAM = ["north_america"] }
        country_pools = { GB = ["europe"] }
        pop_pools     = { LHR = ["europe"] }

        session_affinity     = "cookie"
        session_affinity_ttl = 3600
        session_affinity_attributes = {
          samesite               = "Lax"
          secure                 = "Auto"
          zero_downtime_failover = "sticky"
        }

        adaptive_routing  = { failover_across_pools = true }
        location_strategy = { mode = "resolver_ip", prefer_ecs = "proximity" }
        random_steering = {
          default_weight = 0.5
          pool_weights   = { europe = 0.7, north_america = 0.3 }
        }

        rules = {
          maintenance = {
            condition  = "http.request.uri.path contains \"/maintenance\""
            priority   = 10
            terminates = true
            fixed_response = {
              status_code  = 503
              content_type = "text/plain"
              message_body = "Maintenance."
            }
          }
          api = {
            condition = "http.request.uri.path starts_with \"/api\""
            priority  = 20
            overrides = {
              default_pools   = ["north_america"]
              fallback_pool   = "europe"
              steering_policy = "least_connections"
              region_pools    = { ENAM = ["north_america"] }
            }
          }
        }
      }
    }
  }

  assert {
    condition     = length(output.monitor_ids) == 2
    error_message = "Expected two monitors."
  }

  assert {
    condition     = length(output.monitor_group_ids) == 1
    error_message = "Expected one monitor group."
  }

  assert {
    condition     = length(output.healthcheck_ids) == 1
    error_message = "Expected one standalone health check."
  }

  assert {
    condition     = length(output.pool_ids) == 2
    error_message = "Expected two pools."
  }

  assert {
    condition     = length(output.load_balancer_ids) == 1
    error_message = "Expected one load balancer."
  }

  # Resource attributes are unknown at plan under mock_provider, so assertions
  # stay on the shape of the plan: which keys exist and how many of each.
  assert {
    condition     = contains(keys(output.pools), "europe") && contains(keys(output.pools), "north_america")
    error_message = "Pools should be keyed exactly as they were declared."
  }

  assert {
    condition     = contains(keys(output.load_balancers), "www.example.com")
    error_message = "Load balancers should be keyed exactly as they were declared."
  }
}

run "explicit_names_win_over_map_keys" {
  command = plan

  variables {
    pools = {
      shorthand = {
        name = "explicit-pool-name"
        origins = {
          a = { address = "192.0.2.10" }
        }
      }
    }

    load_balancers = {
      shorthand = {
        name          = "lb.example.com"
        default_pools = ["shorthand"]
        fallback_pool = "shorthand"
      }
    }
  }

  assert {
    condition     = contains(keys(output.pools), "shorthand")
    error_message = "The output map is keyed by the map key even when name is set explicitly."
  }

  assert {
    condition     = contains(keys(output.load_balancers), "shorthand")
    error_message = "The output map is keyed by the map key even when name is set explicitly."
  }
}

run "literal_ids_pass_through_unresolved" {
  command = plan

  variables {
    pools = {
      local_pool = {
        # Not a key in var.monitors, so it is treated as a literal monitor ID.
        monitor = "11111111111111111111111111111111"
        origins = {
          a = { address = "192.0.2.10" }
        }
      }
    }

    load_balancers = {
      "www.example.com" = {
        # First entry is a pool key, second is a literal pool ID.
        default_pools = ["local_pool", "22222222222222222222222222222222"]
        fallback_pool = "22222222222222222222222222222222"
      }
    }
  }

  # A literal ID that matches no map key must not fail resolution. If the
  # lookup fallback were missing, this plan would error rather than assert.
  assert {
    condition     = length(output.pool_ids) == 1 && length(output.load_balancer_ids) == 1
    error_message = "A pool or monitor reference that is not a map key should pass through as a literal ID."
  }
}

# -----------------------------------------------------------------------------
# Submodules that the root module does not compose.
# -----------------------------------------------------------------------------

run "spectrum_single_port_and_range" {
  command = plan

  module {
    source = "./modules/spectrum"
  }

  variables {
    zone_id = "00000000000000000000000000000000"

    applications = {
      ssh = {
        protocol           = "tcp/22"
        dns                = { type = "CNAME", name = "ssh.example.com" }
        origin_direct      = ["tcp://192.0.2.10:22"]
        argo_smart_routing = true
        ip_firewall        = true
        proxy_protocol     = "v2"
        tls                = "off"
        traffic_type       = "direct"
        edge_ips           = { type = "dynamic", connectivity = "all" }
      }
      game = {
        protocol          = "tcp/25565-25575"
        dns               = { type = "CNAME", name = "game.example.com" }
        origin_dns        = { name = "origin.example.net", type = "A", ttl = 600 }
        origin_port_range = "25565-25575"
      }
    }
  }

  assert {
    condition     = length(output.application_ids) == 2
    error_message = "Both Spectrum applications should be planned, one per origin port form."
  }
}

run "addressing_prefixes_and_maps" {
  command = plan

  module {
    source = "./modules/addressing"
  }

  variables {
    account_id = "00000000000000000000000000000000"

    byo_ip_prefixes = {
      primary = {
        cidr                  = "203.0.113.0/24"
        asn                   = 64512
        delegate_loa_creation = true
      }
    }

    address_maps = {
      dedicated = {
        enabled     = true
        default_sni = "example.com"
        ips         = ["203.0.113.10"]
        memberships = {
          zone = { identifier = "00000000000000000000000000000000", kind = "zone" }
        }
      }
    }
  }

  assert {
    condition     = length(output.byo_ip_prefix_ids) == 1 && length(output.address_map_ids) == 1
    error_message = "Expected one BYOIP prefix and one address map."
  }
}

run "magic_network_monitoring" {
  command = plan

  module {
    source = "./modules/monitoring"
  }

  variables {
    account_id = "00000000000000000000000000000000"

    configuration = {
      name             = "example-account"
      default_sampling = 10000
      router_ips       = ["203.0.113.1"]
      warp_devices = {
        branch = {
          id        = "00000000-0000-0000-0000-000000000000"
          name      = "branch"
          router_ip = "203.0.113.2/32"
        }
      }
    }

    rules = {
      flood = {
        type                = "threshold"
        prefixes            = ["203.0.113.0/24"]
        bandwidth_threshold = 1000000000
        duration            = "5m"
      }
      baseline = {
        type               = "zscore"
        prefixes           = ["203.0.113.0/24"]
        zscore_sensitivity = "medium"
        zscore_target      = "bits"
      }
    }
  }

  assert {
    condition     = output.configuration != null
    error_message = "The Magic Network Monitoring configuration should be planned when var.configuration is set."
  }

  assert {
    condition     = length(output.rule_ids) == 2
    error_message = "Expected two Magic Network Monitoring rules."
  }
}

run "magic_wan_tunnels_and_routes" {
  command = plan

  module {
    source = "./modules/magic-wan"
  }

  variables {
    account_id = "00000000000000000000000000000000"

    gre_tunnels = {
      branch-gre = {
        cloudflare_gre_endpoint = "203.0.113.1"
        customer_gre_endpoint   = "198.51.100.1"
        interface_address       = "10.10.10.0/31"
        mtu                     = 1476
        health_check_enabled    = true
        health_check_direction  = "bidirectional"
        health_check_rate       = "mid"
        health_check_type       = "reply"
        bgp                     = { customer_asn = 64512 }
      }
    }

    ipsec_tunnels = {
      branch-ipsec = {
        cloudflare_endpoint    = "203.0.113.2"
        customer_endpoint      = "198.51.100.2"
        interface_address      = "10.10.10.2/31"
        replay_protection      = true
        health_check_enabled   = true
        custom_remote_fqdn_id  = "branch.00000000000000000000000000000000.custom.ipsec.cloudflare.com"
        health_check_direction = "unidirectional"
      }
    }

    static_routes = {
      branch_lan = {
        prefix   = "10.20.0.0/16"
        nexthop  = "10.10.10.1"
        priority = 100
        weight   = 10
        scope    = { colo_regions = ["WEU"] }
      }
    }
  }

  assert {
    condition     = length(output.gre_tunnel_ids) == 1
    error_message = "Expected one GRE tunnel."
  }

  assert {
    condition     = length(output.ipsec_tunnel_ids) == 1
    error_message = "Expected one IPsec tunnel."
  }

  assert {
    condition     = length(output.static_route_ids) == 1
    error_message = "Expected one static route."
  }
}

run "magic_transit_site_topology" {
  command = plan

  module {
    source = "./modules/magic-transit"
  }

  variables {
    account_id = "00000000000000000000000000000000"

    connectors = {
      branch = {
        device_serial_number     = "SERIAL0000000000"
        device_provision_license = true
        activated                = true
      }
    }

    sites = {
      branch = {
        connector_key = "branch"
        location      = { lat = "51.51", lon = "-0.13" }
      }
    }

    site_wans = {
      branch_wan = {
        site_key          = "branch"
        physport          = 1
        static_addressing = { address = "198.51.100.10/30", gateway_address = "198.51.100.9" }
      }
    }

    site_lans = {
      branch_lan = {
        site_key = "branch"
        physport = 2
        vlan_tag = 0
        static_addressing = {
          address = "10.20.0.1/24"
          dhcp_server = {
            dhcp_pool_start = "10.20.0.100"
            dhcp_pool_end   = "10.20.0.200"
            dns_servers     = ["1.1.1.1"]
            dhcp_options = {
              domain_name = { code = 15, type = "text", value = "branch.example.com" }
            }
          }
        }
        routed_subnets = {
          lab = { prefix = "10.20.1.0/24", next_hop = "10.20.0.2" }
        }
      }
      guest_lan = {
        site_key = "branch"
        physport = 3
        vlan_tag = 100
        static_addressing = {
          address    = "10.30.0.1/24"
          dhcp_relay = { server_addresses = ["10.20.0.53"] }
        }
      }
    }

    site_acls = {
      lan_to_guest = {
        site_key       = "branch"
        protocols      = ["tcp", "udp"]
        lan_1          = { lan_key = "branch_lan", ports = [53, 443] }
        lan_2          = { lan_key = "guest_lan", port_ranges = ["8000-8100"] }
        unidirectional = true
      }
    }
  }

  assert {
    condition     = length(output.site_ids) == 1 && length(output.site_lan_ids) == 2 && length(output.site_wan_ids) == 1
    error_message = "Expected one site with two LANs and one WAN."
  }

  assert {
    condition     = length(output.site_acl_ids) == 1
    error_message = "Expected one site ACL."
  }
}
