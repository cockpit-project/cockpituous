all:
	@echo "usage: make containers" >&2
	@echo "       make release-shell" >&2
	@echo "       make release-cockpit" >&2
	@echo "       make release-container" >&2
	@echo "       make release-install" >&2
	@echo "       make check" >&2

check:
	sink/test-logic
	sink/test-sink
	python3 -m pyflakes tasks sink/sink sink/test-sink sink/test-logic tasks/webhook
	python3 -m $$(python3 -m pep8 --version >/dev/null 2>&1 && echo pep8 || echo pycodestyle) --max-line-length=120 --ignore=E722 tasks sink/sink sink/test-logic sink/test-sink tasks/webhook

TAG := $(shell date --iso-8601)
TASK_SECRETS := /var/lib/cockpit-secrets/tasks
WEBHOOK_SECRETS := /var/lib/cockpit-secrets/webhook
TASK_CACHE := /var/cache/cockpit-tasks
DOCKER := $(shell which podman docker 2>/dev/null | head -n1)

containers: images-container release-container tests-container
	@true

images-shell:
	$(DOCKER) run -ti --rm --publish 8080:8080 --publish=8493:8443 \
		--volume=$(TASK_SECRETS):/secrets:ro \
		--volume=$(TASK_CACHE)/images:/cache/images:rw \
		--entrypoint=/bin/bash \
        cockpit/images -i

images-container:
	$(DOCKER) build -t quay.io/cockpit/images:$(TAG) images
	$(DOCKER) tag quay.io/cockpit/images:$(TAG) quay.io/cockpit/images:latest
	$(DOCKER) tag quay.io/cockpit/images:$(TAG) quay.io/cockpit/images:latest

images-push:
	./push-container quay.io/cockpit/images

release-shell:
	$(DOCKER) run -ti --rm --entrypoint=/bin/bash ghcr.io/cockpit-project/release

release-container:
	$(DOCKER) build -t ghcr.io/cockpit-project/release:$(TAG) release
	$(DOCKER) tag ghcr.io/cockpit-project/release:$(TAG) ghcr.io/cockpit-project/release:latest
	$(DOCKER) tag ghcr.io/cockpit-project/release:$(TAG) ghcr.io/cockpit-project/release:latest

release-push:
	./push-container ghcr.io/cockpit-project/release

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
	$(DOCKER) tag quay.io/cockpit/tasks:$(TAG) quay.io/cockpit/tasks:latest

tasks-push:
	./push-container quay.io/cockpit/tasks

tasks-secrets:
	@cd tasks && ./build-secrets $(TASK_SECRETS)

learn-shell:
	$(DOCKER) run -ti --rm \
		--privileged \
		--publish=8080:8080 \
		--volume=$(CURDIR)/learn:/learn \
		--entrypoint=/bin/bash \
        docker.io/cockpit/learn -i

learn-container:
	$(DOCKER) build -t docker.io/cockpit/learn:$(TAG) learn
	$(DOCKER) tag docker.io/cockpit/learn:$(TAG) docker.io/cockpit/learn:latest
	$(DOCKER) tag docker.io/cockpit/learn:$(TAG) docker.io/cockpit/learn:latest

learn-push:
	./push-container docker.io/cockpit/learn
