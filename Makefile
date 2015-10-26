all:
	@echo "usage: make containers" >&2
	@echo "       make release-shell" >&2
	@echo "       make release-container" >&2
	@echo "       make release-install" >&2

base:
	docker build -t cockpit/infra-base base

containers: release-container
	docker build -t cockpit/infra-sink sink
	docker build -t cockpit/infra-files files
	docker build -t cockpit/infra-irc irc

release-shell:
	docker run -ti --rm -v /home/cockpit:/home/user \
		-v $(CURDIR)/release:/usr/local/bin cockpit/infra-release /bin/bash

release-container:
	docker build -t cockpit/infra-release release

release-install: release-container
	cp release/release-runner.service /etc/systemd/system/
	systemctl daemon-reload
	systemctl enable release-runner

verify-install:
	test -d /opt/cockpit || git close https://github.com/cockpit-project/cockpit
	( cd /opt/cockpit/tools && npm install )
	chown -R cockpit /opt/cockpit
	cp verify/cockpit-verify /opt/
	cp verify/cockpit-verify.service /etc/systemd/system/
	systemctl daemon-reload
	systemctl enable cockpit-verify
