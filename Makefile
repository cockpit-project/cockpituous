all:
	@echo "usage: make containers" >&2
	@echo "       make release-shell" >&2

base:
	docker build -t cockpit/infra-base base

containers:
	docker build -t cockpit/infra-sink sink
	docker build -t cockpit/infra-files files
	docker build -t cockpit/infra-irc irc
	docker build -t cockpit/infra-release release

release-shell:
	docker run -ti --rm -v /home/cockpit:/home/user \
		-v $(CURDIR)/release:/opt/scripts cockpit/infra-release /bin/bash
