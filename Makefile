all:
	@echo "usage: make containers" >&2
	@echo "       make tasks-container" >&2
	@echo "       make check" >&2

check:
	python3 -m pyflakes tasks tasks/container/webhook
	python3 -m pycodestyle --max-line-length=120 --ignore=E722 tasks tasks/container/webhook
	if command -v mypy >/dev/null; then mypy test; else echo "SKIP: mypy not installed"; fi
	if command -v ruff >/dev/null; then ruff check test; else echo "SKIP: ruff not installed"; fi

TAG := $(shell date --iso-8601)
TASK_SECRETS := /var/lib/cockpit-secrets/tasks
DOCKER ?= $(shell which podman docker 2>/dev/null | head -n1)

containers: tasks-container
	@true

tasks-container:
	$(DOCKER) build -t ghcr.io/cockpit-project/tasks:$(TAG) tasks/container
	$(DOCKER) tag ghcr.io/cockpit-project/tasks:$(TAG) ghcr.io/cockpit-project/tasks:latest

tasks-secrets:
	@cd tasks && ./build-secrets $(TASK_SECRETS)
