.PHONY: help fmt validate lint docs test security ci clean

TF ?= terraform
DIRS := . ./wrappers $(wildcard ./modules/*) $(wildcard ./examples/*)

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

fmt: ## Format all Terraform files
	$(TF) fmt -recursive

validate: ## Init and validate every Terraform directory
	@for d in $(DIRS); do \
		echo ">> $$d"; \
		$(TF) -chdir=$$d init -backend=false -input=false >/dev/null || exit 1; \
		$(TF) -chdir=$$d validate || exit 1; \
	done

lint: ## Run tflint across the repository
	@command -v tflint >/dev/null 2>&1 || { echo "tflint is required: https://github.com/terraform-linters/tflint"; exit 1; }
	tflint --init
	tflint --recursive --format compact

docs: ## Regenerate the terraform-docs block in README.md
	@command -v terraform-docs >/dev/null 2>&1 || { echo "terraform-docs is required: https://terraform-docs.io/"; exit 1; }
	terraform-docs markdown table --output-file README.md --output-mode inject .
	@for d in $(wildcard ./modules/*) ./wrappers; do \
		terraform-docs markdown table --output-file README.md --output-mode inject $$d; \
	done

test: ## Run the mocked terraform tests, no credentials needed
	$(TF) init -backend=false -input=false
	$(TF) test -filter=tests/defaults.tftest.hcl -filter=tests/validations.tftest.hcl -verbose

security: ## Run trivy, checkov and gitleaks
	@command -v trivy >/dev/null 2>&1 && trivy config . --severity MEDIUM,HIGH,CRITICAL || echo "trivy not installed, skipping"
	@command -v checkov >/dev/null 2>&1 && checkov -d . --compact --quiet || echo "checkov not installed, skipping"
	@command -v gitleaks >/dev/null 2>&1 && gitleaks detect --source . --redact || echo "gitleaks not installed, skipping"

ci: fmt validate lint docs test ## Everything CI runs, locally

clean: ## Remove local Terraform state and plugin caches
	find . -type d -name .terraform -prune -exec rm -rf {} +
	find . -type f -name '*.tfplan' -delete
