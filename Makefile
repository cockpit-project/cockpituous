all:
	@echo "usage: make containers" >&2
	@echo "       make release-shell" >&2
	@echo "       make release-container" >&2
	@echo "       make release-install" >&2

docker-running:
	systemctl start docker

TAG := $(shell date --iso-8601)
TEST_SECRETS := /var/lib/cockpit-tests/secrets
TEST_CACHE := /var/cache/cockpit-tests

base-container: docker-running
	docker build -t docker.io/cockpit/infra-base:$(TAG) base
	docker tag docker.io/cockpit/infra-base:$(TAG) docker.io/cockpit/infra-base:latest
	docker tag cockpit/infra-base:$(TAG) cockpit/infra-base:latest

base-push: docker-running
	base/push-container docker.io/cockpit/infra-base

containers: images-container release-container tests-container
	@true

images-shell: docker-running
	docker run -ti --rm --publish=8493:443 \
		--volume=$(TEST_SECRETS):/secrets:ro \
		--volume=$(TEST_CACHE):/cache:rw \
		--entrypoint=/bin/bash \
        cockpit/images -i

images-container: docker-running
	docker build -t docker.io/cockpit/images:$(TAG) images
	docker tag docker.io/cockpit/images:$(TAG) docker.io/cockpit/images:latest
	docker tag docker.io/cockpit/images:$(TAG) cockpit/images:latest

images-push: docker-running
	base/push-container docker.io/cockpit/images

release-shell: docker-running
	test -d /home/cockpit/release || git clone https://github.com/cockpit-project/cockpit /home/cockpit/release
	chown -R cockpit:cockpit /home/cockpit/release
	docker run -ti --rm -v /home/cockpit:/home/user:rw \
		--privileged \
		--volume=/home/cockpit/release:/build:rw \
		--volume=$(CURDIR)/release:/usr/local/bin \
		--entrypoint=/bin/bash docker.io/cockpit/release

release-container: docker-running
	docker build -t cockpit/release:staged release
	docker rm -f cockpit-release-stage || true
	docker run --privileged --name=cockpit-release-stage \
		--entrypoint=/usr/local/bin/Dockerfile.sh cockpit/release:staged
	docker commit --change='ENTRYPOINT ["/usr/local/bin/release-runner"]' \
		cockpit-release-stage docker.io/cockpit/release:$(TAG)
	docker tag docker.io/cockpit/release:$(TAG) docker.io/cockpit/release:latest
	docker tag docker.io/cockpit/release:$(TAG) cockpit/release:latest
	docker rm -f cockpit-release-stage
	docker rmi cockpit/release:staged
	@true

release-push: docker-running
	base/push-container docker.io/cockpit/release

release-install: release-container
	cp release/cockpit-release.service /etc/systemd/system/
	systemctl daemon-reload
	systemctl enable cockpit-release

tests-shell: docker-running
	docker run -ti --rm \
		--privileged --uts=host \
		--volume=$(CURDIR)/tests:/usr/local/bin \
		--volume=$(TEST_SECRETS):/secrets:ro \
		--volume=$(TEST_CACHE):/cache:rw \
		--entrypoint=/bin/bash \
        docker.io/cockpit/tests -i

tests-container: docker-running
	docker build -t docker.io/cockpit/tests:$(TAG) tests
	docker tag docker.io/cockpit/tests:$(TAG) docker.io/cockpit/tests:latest
	docker tag docker.io/cockpit/tests:$(TAG) cockpit/tests:latest

tests-push: docker-running
	base/push-container docker.io/cockpit/tests

tests-secrets:
	@cd tests && ./build-secrets $(TEST_SECRETS)
