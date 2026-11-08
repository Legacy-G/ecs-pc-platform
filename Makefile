include ci/versions.env
export

SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c

AWS_PROFILE ?= damolak
AWS_REGION  ?= eu-north-1
TF_ENV      ?= dev

.PHONY: help up down test lint scan prose cost-check \
        tf-fmt tf-validate tf-lint tf-docs plan apply destroy smoke diagrams

help:
	@echo "Targets: up down test lint scan prose cost-check tf-fmt tf-validate tf-lint tf-docs plan apply destroy smoke diagrams"

up:
	docker compose up --build -d

down:
	docker compose down --remove-orphans

test:
	pytest services/api/tests

lint: prose
	pre-commit run --all-files

scan:
	gitleaks detect --source . --verbose --redact
	docker run --rm -i hadolint/hadolint:v$(HADOLINT_VERSION) < services/api/Dockerfile
	docker run --rm -v "$$(pwd):/work" -w /work aquasec/trivy:$(TRIVY_VERSION) fs --scanners vuln,secret,misconfig --exit-code 1 --severity HIGH,CRITICAL .

prose:
	bash scripts/check-prose.sh

cost-check:
	AWS_PROFILE=$(AWS_PROFILE) AWS_REGION=$(AWS_REGION) bash scripts/cost-check.sh

tf-fmt:
	terraform fmt -check -recursive infra

tf-validate:
	@for dir in infra/bootstrap infra/envs/shared infra/envs/dev infra/envs/prod; do \
		if [ -d "$$dir" ]; then \
			echo "Validating $$dir"; \
			terraform -chdir="$$dir" init -backend=false -input=false >/dev/null; \
			terraform -chdir="$$dir" validate; \
		fi; \
	done

tf-lint: tf-fmt tf-validate
	docker run --rm -v "$$(pwd):/data" -t ghcr.io/terraform-linters/tflint:v$(TFLINT_VERSION) --chdir=infra/envs/$(TF_ENV)

tf-docs:
	@for mod in infra/modules/*; do \
		if [ -d "$$mod" ]; then \
			docker run --rm -v "$$(pwd)/$$mod:/terraform-docs" quay.io/terraform-docs/terraform-docs:$(TERRAFORM_DOCS_VERSION) markdown table --output-file README.md --output-mode inject /terraform-docs; \
		fi; \
	done

plan:
	AWS_PROFILE=$(AWS_PROFILE) terraform -chdir=infra/envs/$(TF_ENV) plan -input=false

apply:
	@echo "Refusing unattended apply. Print hourly/daily cost estimate and obtain explicit chat approval first."
	@exit 1

destroy:
	@echo "Refusing unattended destroy. Obtain explicit chat approval first, then run scripts/cost-check.sh."
	@exit 1

smoke:
	bash scripts/smoke.sh "$(ALB_URL)" "$(EXPECTED_SHA)"

diagrams:
	python docs/architecture/generate_diagrams.py
