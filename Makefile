all:
	@echo "usage: make containers" >&2
	@echo "       make release-shell" >&2
	@echo "       make release-container" >&2
	@echo "       make release-install" >&2

docker-running:
	systemctl start docker

TAG := $(shell date --iso-8601)

base-container: docker-running
	docker build -t cockpit/infra-base:$(TAG) base
	docker tag cockpit/infra-base:$(TAG) cockpit/infra-base:latest

base-push: docker-running
	base/push-container cockpit/infra-base

containers: release-container tests-container
	@true

release-shell: docker-running
	test -d /home/cockpit/release || git clone https://github.com/cockpit-project/cockpit /home/cockpit/release
	chown -R cockpit:cockpit /home/cockpit/release
	docker run -ti --rm -v /home/cockpit:/home/user:rw \
		--privileged \
		--volume=/home/cockpit/release:/build:rw \
		--volume=$(CURDIR)/release:/usr/local/bin \
		--entrypoint=/bin/bash cockpit/infra-release

release-container: docker-running
	docker build -t cockpit/infra-release:staged release
	docker rm -f cockpit-release-stage || true
	docker run --privileged --name=cockpit-release-stage \
		--entrypoint=/usr/local/bin/Dockerfile.sh cockpit/infra-release:staged
	docker commit --change='ENTRYPOINT ["/usr/local/bin/release-runner"]' \
		cockpit-release-stage cockpit/infra-release:$(TAG)
	docker tag cockpit/infra-release:$(TAG) cockpit/infra-release:latest
	docker rm -f cockpit-release-stage
	docker rmi cockpit/infra-release:staged
	@true

release-push: docker-running
	base/push-container cockpit/infra-release

release-install: release-container
	cp release/cockpit-release.service /etc/systemd/system/
	systemctl daemon-reload
	systemctl enable cockpit-release

tests-shell: docker-running
	docker run -ti --rm \
		--privileged --uts=host \
		--volume=$(CURDIR)/tests:/usr/local/bin \
		--volume=/var/lib/cockpit-tests/secrets:/secrets \
		--volume=/var/lib/cockpit-tests/images:/images:rw \
		--entrypoint=/bin/bash \
        cockpit/tests -i

tests-container: docker-running
	docker build -t cockpit/tests:$(TAG) tests
	docker tag cockpit/tests:$(TAG) cockpit/tests:latest

tests-push: docker-running
	base/push-container cockpit/tests

tests-secrets:
	@sh -c "cd tests && ./build-secrets /var/lib/cockpit-tests/secrets"
