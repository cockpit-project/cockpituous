all:
	@echo "usage: make containers" >&2
	@echo "       make tasks-shell" >&2
	@echo "       make tasks-container" >&2
	@echo "       make tasks-push" >&2
	@echo "       make check" >&2

check:
	python3 -m pyflakes tasks tasks/webhook
	python3 -m pycodestyle --max-line-length=120 --ignore=E722 tasks tasks/webhook

TAG := $(shell date --iso-8601)
TASK_SECRETS := /var/lib/cockpit-secrets/tasks
WEBHOOK_SECRETS := /var/lib/cockpit-secrets/webhook
TASK_CACHE := /var/cache/cockpit-tasks
DOCKER ?= $(shell which podman docker 2>/dev/null | head -n1)

containers: tasks-container
	@true

tasks-shell:
	$(DOCKER) run -ti --rm \
		--shm-size=1024m \
		--volume=$(CURDIR)/tasks:/usr/local/bin \
		--volume=$(TASK_SECRETS):/secrets:ro \
		--volume=$(WEBHOOK_SECRETS):/run/secrets/webhook/:ro \
		--volume=$(TASK_CACHE):/cache:rw \
		--entrypoint=/bin/bash \
        quay.io/cockpit/tasks -i

tasks-container:
	$(DOCKER) build -t quay.io/cockpit/tasks:$(TAG) tasks
	$(DOCKER) tag quay.io/cockpit/tasks:$(TAG) quay.io/cockpit/tasks:latest

tasks-push:
	./push-container quay.io/cockpit/tasks

tasks-secrets:
	@cd tasks && ./build-secrets $(TASK_SECRETS)
