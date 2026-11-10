include ci/versions.env
export

SHELL := bash

AWS_PROFILE ?= damolak
AWS_REGION  ?= eu-north-1
TF_ENV      ?= dev

.PHONY: help up local-down bootstrap down nuke test lint scan prose cost-check evidence \
        tf-fmt tf-validate tf-test tf-lint tf-docs plan apply destroy smoke diagrams \
        jenkins-up jenkins-down

help:
	@echo "Targets: up local-down bootstrap down nuke test lint scan prose cost-check evidence tf-fmt tf-validate tf-test tf-lint tf-docs plan apply destroy smoke diagrams jenkins-up jenkins-down"

jenkins-up:
	docker compose --env-file ci/jenkins/.jenkins.env -f ci/jenkins/docker-compose.yml up --build -d

jenkins-down:
	docker compose --env-file ci/jenkins/.jenkins.env -f ci/jenkins/docker-compose.yml down

up:
	docker compose up --build -d

local-down:
	docker compose down --remove-orphans

bootstrap:
	AWS_PROFILE=$(AWS_PROFILE) AWS_REGION=$(AWS_REGION) bash scripts/bootstrap.sh

down:
	AWS_PROFILE=$(AWS_PROFILE) AWS_REGION=$(AWS_REGION) bash scripts/down.sh

nuke:
	AWS_PROFILE=$(AWS_PROFILE) AWS_REGION=$(AWS_REGION) bash scripts/nuke.sh

test:
	pytest services/api/tests

lint: prose
	pre-commit run --all-files

scan:
	gitleaks detect --source . --verbose --redact
	docker run --rm -i hadolint/hadolint:v$(HADOLINT_VERSION) < services/api/Dockerfile
	docker run --rm -v "$$(pwd):/work" -w /work aquasec/trivy:$(TRIVY_VERSION) config --severity HIGH,CRITICAL --exit-code 1 infra

prose:
	bash scripts/check-prose.sh

cost-check:
	AWS_PROFILE=$(AWS_PROFILE) AWS_REGION=$(AWS_REGION) bash scripts/cost-check.sh

evidence:
	bash scripts/generate-evidence.sh

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

tf-test:
	terraform -chdir=infra/modules/network init -backend=false -input=false >/dev/null
	terraform -chdir=infra/modules/network test
	terraform -chdir=infra/modules/ecs-service init -backend=false -input=false >/dev/null
	terraform -chdir=infra/modules/ecs-service test

tf-lint: tf-fmt tf-validate tf-test
	tflint --init --config "$$(pwd)/.tflint.hcl"
	@for dir in infra/bootstrap infra/envs/shared infra/envs/dev infra/envs/prod; do \
		echo "Running tflint in $$dir"; \
		tflint --config "$$(pwd)/.tflint.hcl" --chdir="$$dir"; \
	done

tf-docs:
	@for mod in infra/modules/*; do \
		if [ -d "$$mod" ]; then \
			terraform-docs markdown table --output-file README.md --output-mode inject "$$mod"; \
		fi; \
	done

plan:
	AWS_PROFILE=$(AWS_PROFILE) terraform -chdir=infra/envs/$(TF_ENV) plan -input=false

apply:
	@echo "Refusing unattended apply. Print hourly/daily cost estimate (USD 0.0574/hr, USD 1.38/day) and obtain explicit chat approval first."
	@exit 1

destroy:
	@echo "Refusing unattended destroy. Use 'make down' (dev stack) or 'make nuke' (full teardown) after approval."
	@exit 1

smoke:
	bash scripts/smoke.sh "$(ALB_URL)" "$(EXPECTED_SHA)"

diagrams:
	python docs/architecture/generate_diagrams.py
