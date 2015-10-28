all:
	@echo "usage: make containers" >&2
	@echo "       make release-shell" >&2
	@echo "       make release-container" >&2
	@echo "       make release-install" >&2

base-container:
	docker build -t cockpit/infra-base base

containers: release-container verify-container
	@true

release-shell:
	docker run -ti --rm -v /home/cockpit:/home/user \
		-v $(CURDIR)/release:/usr/local/bin cockpit/infra-release /bin/bash

release-container:
	docker build -t cockpit/infra-release release

release-install: release-container
	cp release/release-runner.service /etc/systemd/system/
	systemctl daemon-reload
	systemctl enable release-runner

verify-shell:
	docker run -ti --rm \
		--volume /home/cockpit:/home/user \
		--volume $(CURDIR)/verify:/usr/local/bin \
		--volume=/opt/verify:/build:rw \
		--net=host --pid=host --privileged --entrypoint=/bin/bash \
        cockpit/infra-verify -i

verify-container:
	docker build -t cockpit/infra-verify verify

verify-install: verify-container
	cp verify/cockpit-verify.service /etc/systemd/system/
	systemctl daemon-reload
	systemctl enable cockpit-verify
