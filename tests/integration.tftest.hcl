# Applies against a real Cloudflare test account.
# Runs on a schedule and on manual dispatch only, never on pull requests,
# because fork pull requests cannot read organisation secrets.
#
# The run block targets examples/basic rather than the root module directly, so
# the load balancer hostname can be built from the test zone's real DNS name.
# Cloudflare rejects a load balancer whose name is not a hostname inside the
# zone, and the root module has no reason to take a zone name of its own.
#
# Scope is deliberately the load balancing stack only. Spectrum needs a paid add
# on, and Magic WAN and Magic Transit need enterprise onboarding, so none of
# them can be applied on an ordinary test account.

run "apply_and_destroy" {
  command = apply

  module {
    source = "./examples/basic"
  }

  variables {
    account_id = null # supplied by TF_VAR_account_id
    zone_id    = null # supplied by TF_VAR_zone_id
    zone_name  = null # supplied by TF_VAR_zone_name
  }

  assert {
    condition     = output.module.enabled == true
    error_message = "Module did not report enabled after apply."
  }

  # These assertions need a real apply. Under mock_provider every resource
  # attribute is unknown at plan, so key to name and key to ID resolution can
  # only be checked here.
  assert {
    condition     = output.module.pools["primary"].name == "primary"
    error_message = "Pool name should fall back to the map key."
  }

  assert {
    condition     = length(output.module.pools["primary"].origins) == 2
    error_message = "Both origins should reach the pool."
  }

  assert {
    condition     = output.module.pools["primary"].monitor == output.module.monitor_ids["http"]
    error_message = "The pool's monitor key was not resolved to the created monitor ID."
  }

  assert {
    condition = contains(
      output.module.load_balancers["www.${var.zone_name}"].default_pools,
      output.pool_ids["primary"],
    )
    error_message = "The load balancer's pool key was not resolved to the created pool ID."
  }

  assert {
    condition     = output.load_balancer_hostnames["www.${var.zone_name}"] == "www.${var.zone_name}"
    error_message = "Load balancer hostname should fall back to the map key."
  }
}
