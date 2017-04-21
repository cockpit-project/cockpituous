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
	{ \
	ID=`docker images -q cockpit/infra-base:latest`; \
	if [ `echo "$$ID" | wc -w` -ne "1" ]; then \
		echo "Expected exactly one image matching 'cockpit/infra-base:latest'"; \
		exit 1; \
	fi; \
	TAGS=`docker images --format "table {{.Tag}}\t{{.ID}}" | grep $$ID | awk '{print $$1}'`; \
	if [ `echo "$$TAGS" | wc -w` -ne "2" ]; then \
		echo "Expected exactly two tags for the image to push: latest and one other"; \
		exit 1; \
	fi; \
	for PUSHTAG in $$TAGS; do \
		docker push "cockpit/infra-base:$$PUSHTAG"; \
	done \
	}
	@true

containers: release-container verify-container
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
	docker rmi cockpit/infra-release:staged
	docker rm -f cockpit-release-stage
	@true

release-push: docker-running
	{ \
	ID=`docker images -q cockpit/infra-release:latest`; \
	if [ `echo "$$ID" | wc -w` -ne "1" ]; then \
		echo "Expected exactly one image matching 'cockpit/infra-release:latest'"; \
		exit 1; \
	fi; \
	TAGS=`docker images --format "table {{.Tag}}\t{{.ID}}" | grep $$ID | awk '{print $$1}'`; \
	if [ `echo "$$TAGS" | wc -w` -ne "2" ]; then \
		echo "Expected exactly two tags for the image to push: latest and one other"; \
		exit 1; \
	fi; \
	for PUSHTAG in $$TAGS; do \
		docker push "cockpit/infra-release:$$PUSHTAG"; \
	done \
	}
	@true

release-install: release-container
	cp release/cockpit-release.service /etc/systemd/system/
	systemctl daemon-reload
	systemctl enable cockpit-release

verify-shell: docker-running
	docker run -ti --rm \
		--privileged \
		--volume /home/cockpit:/home/user \
		--volume $(CURDIR)/verify:/usr/local/bin \
		--volume=/opt/verify:/build:rw \
		--net=host --pid=host --privileged --entrypoint=/bin/bash \
        cockpit/infra-verify -i

verify-container: docker-running
	docker build -t cockpit/infra-verify:$(TAG) verify
	docker tag cockpit/infra-verify:$(TAG) cockpit/infra-verify:latest

verify-push: docker-running
		{ \
		ID=`docker images -q cockpit/infra-verify:latest`; \
		if [ `echo "$$ID" | wc -w` -ne "1" ]; then \
			echo "Expected exactly one image matching 'cockpit/infra-verify:latest'"; \
			exit 1; \
		fi; \
		TAGS=`docker images --format "table {{.Tag}}\t{{.ID}}" | grep $$ID | awk '{print $$1}'`; \
		if [ `echo "$$TAGS" | wc -w` -ne "2" ]; then \
			echo "Expected exactly two tags for the image to push: latest and one other"; \
			exit 1; \
		fi; \
		for PUSHTAG in $$TAGS; do \
			docker push "cockpit/infra-verify:$$PUSHTAG"; \
		done \
		}
		@true

verify-install: verify-container
	cp verify/cockpit-verify.service /etc/systemd/system/
	systemctl daemon-reload
	systemctl enable cockpit-verify
