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
	python2 -m pyflakes sink/sink sink/test-sink
	python3 -m pyflakes tasks sink/test-logic tasks/webhook

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
	$(DOCKER) build -t docker.io/cockpit/images:$(TAG) images
	$(DOCKER) tag docker.io/cockpit/images:$(TAG) docker.io/cockpit/images:latest
	$(DOCKER) tag docker.io/cockpit/images:$(TAG) cockpit/images:latest

images-push:
	./push-container docker.io/cockpit/images

release-shell:
	test -d /home/cockpit/release || git clone https://github.com/cockpit-project/cockpit /home/cockpit/release
	chown -R cockpit:cockpit /home/cockpit/release
	$(DOCKER) run -ti --rm -v /home/cockpit:/home/user:rw \
		--privileged \
		--env=RELEASE_SINK=fedorapeople.org \
		--volume=/home/cockpit:/home/user:rw \
		--volume=/home/cockpit/release:/build:rw \
		--volume=$(CURDIR)/release:/usr/local/bin \
		--entrypoint=/bin/bash docker.io/cockpit/release

# run release container for a Cockpit release
release-cockpit:
	test -d /home/cockpit/release || git clone https://github.com/cockpit-project/cockpit /home/cockpit/release
	chown -R cockpit:cockpit /home/cockpit/release
	$(DOCKER) run -ti --rm -v /home/cockpit:/home/user:rw \
		--privileged \
		--env=RELEASE_SINK=fedorapeople.org \
		--volume=/home/cockpit:/home/user:rw \
		--volume=/home/cockpit/release:/build:rw \
		--volume=$(CURDIR)/release:/usr/local/bin \
		docker.io/cockpit/release \
		-r https://github.com/cockpit-project/cockpit /build/tools/cockpituous-release

release-container:
	$(DOCKER) build -t docker.io/cockpit/release:$(TAG) release
	$(DOCKER) tag docker.io/cockpit/release:$(TAG) docker.io/cockpit/release:latest
	$(DOCKER) tag docker.io/cockpit/release:$(TAG) cockpit/release:latest

release-push:
	./push-container docker.io/cockpit/release

tasks-shell:
	$(DOCKER) run -ti --rm \
		--shm-size=1024m \
		--volume=$(CURDIR)/tasks:/usr/local/bin \
		--volume=$(TASK_SECRETS):/secrets:ro \
		--volume=$(WEBHOOK_SECRETS):/run/webhook/secrets:ro \
		--volume=$(TASK_CACHE):/cache:rw \
		--entrypoint=/bin/bash \
        docker.io/cockpit/tasks -i

tasks-container:
	$(DOCKER) build -t docker.io/cockpit/tasks:$(TAG) tasks
	$(DOCKER) tag docker.io/cockpit/tasks:$(TAG) docker.io/cockpit/tasks:latest
	$(DOCKER) tag docker.io/cockpit/tasks:$(TAG) cockpit/tasks:latest

tasks-push:
	./push-container docker.io/cockpit/tasks

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
	$(DOCKER) tag docker.io/cockpit/learn:$(TAG) cockpit/learn:latest

learn-push:
	./push-container docker.io/cockpit/learn
