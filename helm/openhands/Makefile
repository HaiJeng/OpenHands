.PHONY: help install upgrade uninstall lint validate test clean deploy-production deploy-dev

# Default target
help:
	@echo "OpenHands Helm Chart - Common Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@echo "  install          Install OpenHands using default configuration"
	@echo "  install-dev       Install OpenHands for development"
	@echo "  install-prod     Install OpenHands for production"
	@echo "  upgrade          Upgrade existing OpenHands installation"
	@echo "  uninstall        Uninstall OpenHands"
	@echo "  status          Show OpenHands release status"
	@echo "  lint           Lint the Helm chart"
	@echo "  validate        Validate YAML syntax"
	@echo "  template       Render templates without installing"
	@echo "  dry-run        Simulate install (dry-run)"
	@echo "  logs           Show OpenHands logs"
	@echo "  shell          Open shell in OpenHands pod"
	@echo "  port-forward    Port forward to access OpenHands locally"
	@echo "  test           Run tests"
	@echo "  clean          Remove generated files"
	@echo ""
	@echo "Examples:"
	@echo "  make install RELEASE=my-openhands NAMESPACE=openhands"
	@echo "  make install-dev API_KEY=sk-..."
	@echo "  make logs"

# Variables
RELEASE ?= openhands
NAMESPACE ?= default
API_KEY ?=
MODEL ?= gpt-4o
IMAGE_TAG ?= latest
RUNTIME_TAG ?= latest
AGENT_TAG ?= latest

# Install targets
install:
	helm install $(RELEASE) . \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--set openhands.llm.apiKey=$(API_KEY) \
		--set openhands.llm.model=$(MODEL)

install-dev:
	@echo "Installing OpenHands in development mode..."
	helm install $(RELEASE) . \
		--namespace $(NAMESPACE) \
		--create-namespace \
		-f values-dev-example.yaml \
		--set openhands.llm.apiKey=$(API_KEY)

install-prod:
	@echo "Installing OpenHands in production mode..."
	helm install $(RELEASE) . \
		--namespace $(NAMESPACE) \
		--create-namespace \
		-f values-production-example.yaml \
		--set secret.enabled=true \
		--set secret.existingSecret=openhands-secrets

install-custom:
	@echo "Installing OpenHands with custom image tags..."
	helm install $(RELEASE) . \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--set image.tag=$(IMAGE_TAG) \
		--set image.runtime.tag=$(RUNTIME_TAG) \
		--set image.agentServer.tag=$(AGENT_TAG) \
		--set openhands.llm.apiKey=$(API_KEY) \
		--set openhands.llm.model=$(MODEL)

# Upgrade targets
upgrade:
	helm upgrade $(RELEASE) . \
		--namespace $(NAMESPACE) \
		--set openhands.llm.apiKey=$(API_KEY) \
		--set openhands.llm.model=$(MODEL)

upgrade-custom:
	helm upgrade $(RELEASE) . \
		--namespace $(NAMESPACE) \
		--set image.tag=$(IMAGE_TAG) \
		--set image.runtime.tag=$(RUNTIME_TAG) \
		--set image.agentServer.tag=$(AGENT_TAG)

# Uninstall
uninstall:
	helm uninstall $(RELEASE) --namespace $(NAMESPACE)

# Status and info
status:
	helm status $(RELEASE) --namespace $(NAMESPACE)
	@echo ""
	@echo "Pods:"
	kubectl get pods -n $(NAMESPACE) -l app.kubernetes.io/name=openhands
	@echo ""
	@echo "Services:"
	kubectl get svc -n $(NAMESPACE) -l app.kubernetes.io/name=openhands
	@echo ""
	@echo "PVCs:"
	kubectl get pvc -n $(NAMESPACE) -l app.kubernetes.io/name=openhands

# Validation
lint:
	helm lint .

validate:
	@echo "Validating YAML syntax..."
	@for file in Chart.yaml values.yaml values-*-example.yaml; do \
		if command -v yamllint >/dev/null 2>&1; then \
			yamllint $$file; \
		else \
			echo "yamllint not installed, skipping..."; \
		fi; \
	done

template:
	helm template $(RELEASE) . \
		--namespace $(NAMESPACE) \
		--set openhands.llm.apiKey=test-key

dry-run:
	helm install $(RELEASE) . \
		--namespace $(NAMESPACE) \
		--dry-run \
		--debug

# Logs and debugging
logs:
	kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/name=openhands,app.kubernetes.io/instance=$(RELEASE) --tail=100 -f

logs-all:
	kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/name=openhands,app.kubernetes.io/instance=$(RELEASE) --all-containers=true --tail=100 -f

shell:
	@POD=$$(kubectl get pod -n $(NAMESPACE) -l app.kubernetes.io/name=openhands,app.kubernetes.io/instance=$(RELEASE) -o jsonpath='{.items[0].metadata.name}'); \
	kubectl exec -it -n $(NAMESPACE) $$POD -- /bin/bash

port-forward:
	@echo "Port forwarding to http://localhost:3000"
	@kubectl port-forward -n $(NAMESPACE) svc/$(RELEASE) 3000:3000

describe:
	kubectl describe pod -n $(NAMESPACE) -l app.kubernetes.io/name=openhands,app.kubernetes.io/instance=$(RELEASE)

events:
	kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp'

# Testing
test:
	@echo "Running Helm tests..."
	helm test $(RELEASE) --namespace $(NAMESPACE)

# Package
package:
	helm package .

# Clean
clean:
	rm -f *.tgz
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete

# Dependencies
deps:
	@echo "No dependencies to install"

# Show values
show-values:
	helm show values .

# Get manifest
get-manifest:
	helm get manifest $(RELEASE) --namespace $(NAMESPACE)
