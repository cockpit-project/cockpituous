all:
	@echo "usage: make containers" >&2
	@echo "       make tasks-container" >&2
	@echo "       make tasks-push" >&2
	@echo "       make check" >&2

check:
	python3 -m pyflakes tasks tasks/container/webhook
	python3 -m pycodestyle --max-line-length=120 --ignore=E722 tasks tasks/container/webhook

TAG := $(shell date --iso-8601)
TASK_SECRETS := /var/lib/cockpit-secrets/tasks
DOCKER ?= $(shell which podman docker 2>/dev/null | head -n1)

containers: tasks-container
	@true

tasks-container:
	$(DOCKER) build -t quay.io/cockpit/tasks:$(TAG) tasks/container
	$(DOCKER) tag quay.io/cockpit/tasks:$(TAG) quay.io/cockpit/tasks:latest

tasks-push:
	./push-container quay.io/cockpit/tasks

tasks-secrets:
	@cd tasks && ./build-secrets $(TASK_SECRETS)
