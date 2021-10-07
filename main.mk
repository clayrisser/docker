# File: /main.mk
# Project: mkpm-docker
# File Created: 07-10-2021 16:58:49
# Author: Clay Risser
# -----
# Last Modified: 07-10-2021 17:13:41
# Modified By: Clay Risser
# -----
# BitSpur Inc (c) Copyright 2021
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

export TAG ?= latest
export VERSION ?= 0.0.1
export CONTEXT ?= .
export CONTAINER_NAME ?= $(shell $(ECHO) $(NAME) | $(SED) "s|[\/-]|_|g")
export MAJOR := $(shell $(ECHO) $(VERSION) | $(CUT) -d. -f1)
export MINOR := $(shell $(ECHO) $(VERSION) | $(CUT) -d. -f2)
export PATCH := $(shell $(ECHO) $(VERSION) | $(CUT) -d. -f3)

DOCKER_COMPOSE ?= docker-compose
DOCKER ?= docker

.PHONY: build
build: $(CONTEXT)/.dockerignore
	@$(DOCKER_COMPOSE) -f docker-build.yaml build $(ARGS) main
	@$(MAKE) -s tag

.PHONY: tag
tag:
	@$(DOCKER) tag ${IMAGE}:${TAG} ${IMAGE}:${MAJOR}
	@$(DOCKER) tag ${IMAGE}:${TAG} ${IMAGE}:${MAJOR}.${MINOR}
	@$(DOCKER) tag ${IMAGE}:${TAG} ${IMAGE}:${MAJOR}.${MINOR}.${PATCH}

.PHONY: pull
pull:
	@$(DOCKER_COMPOSE) -f docker-build.yaml pull $(ARGS)

.PHONY: push
push:
	@$(DOCKER_COMPOSE) -f docker-build.yaml push $(ARGS)

.PHONY: ssh
ssh:
	@($(DOCKER) ps | $(GREP) -E "$(NAME)$$" $(NOOUT)) && \
		$(DOCKER) exec -it $(NAME) /bin/sh || \
		$(DOCKER) run --rm -it --entrypoint /bin/sh $(IMAGE):$(TAG)

.PHONY: logs
logs:
	@$(DOCKER_COMPOSE) logs -f $(ARGS)

.PHONY: up
up:
	@$(DOCKER_COMPOSE) up $(ARGS)

.PHONY: stop
stop:
	@$(DOCKER_COMPOSE) stop $(ARGS)

.PHONY: clean
clean:
	-@$(DOCKER_COMPOSE) kill
	-@$(DOCKER_COMPOSE) down -v --remove-orphans
	-@$(DOCKER_COMPOSE) rm -v

ifneq (,$(wildcard $(CONTEXT)/.gitignore))
$(CONTEXT)/.dockerignore: $(CONTEXT)/.gitignore
	@$(CP) $< $@
else
$(CONTEXT)/.dockerignore:
	@$(TOUCH) $@
endif
