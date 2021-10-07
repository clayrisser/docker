# File: /main.mk
# Project: mkpm-docker
# File Created: 07-10-2021 16:58:49
# Author: Clay Risser
# -----
# Last Modified: 07-10-2021 18:13:35
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

export CONTEXT ?= .
CONTEXT := $(abspath $(CONTEXT))
export REGISTRY ?=
export TAG ?= latest
export VERSION ?= 0.0.1
export DOCKERFILE ?= $(CURDIR)/Dockerfile
ifeq (,$(REGISTRY))
	export IMAGE := $(NAME)
else
	export IMAGE := $(REGISTRY)/$(NAME)
endif
export CONTAINER_NAME ?= $(shell $(ECHO) $(NAME) $(NOFAIL) | $(SED) "s|[\/-]|_|g" $(NOFAIL))
export MAJOR := $(shell $(ECHO) $(VERSION) $(NOFAIL) | $(CUT) -d. -f1 $(NOFAIL))
export MINOR := $(shell $(ECHO) $(VERSION) $(NOFAIL) | $(CUT) -d. -f2 $(NOFAIL))
export PATCH := $(shell $(ECHO) $(VERSION) $(NOFAIL) | $(CUT) -d. -f3 $(NOFAIL))

DOCKER_COMPOSE ?= docker-compose
DOCKER ?= docker

DOCKER_TMP := $(MKPM_TMP)/docker

.PHONY: build
build: $(DOCKER_TMP)/docker-build.yaml $(CONTEXT)/.dockerignore
	@$(DOCKER_COMPOSE) -f $< build $(ARGS) main
	@$(MAKE) -s tag

.PHONY: tag
tag:
	@$(DOCKER) tag ${IMAGE}:${TAG} ${IMAGE}:${MAJOR}
	@$(DOCKER) tag ${IMAGE}:${TAG} ${IMAGE}:${MAJOR}.${MINOR}
	@$(DOCKER) tag ${IMAGE}:${TAG} ${IMAGE}:${MAJOR}.${MINOR}.${PATCH}

.PHONY: tags
tags:
	@echo ${IMAGE}:${TAG}
	@echo ${IMAGE}:${MAJOR}
	@echo ${IMAGE}:${MAJOR}.${MINOR}
	@echo ${IMAGE}:${MAJOR}.${MINOR}.${PATCH}

.PHONY: pull
pull: $(DOCKER_TMP)/docker-build.yaml
	@$(DOCKER_COMPOSE) -f $< pull $(ARGS)

.PHONY: push
push: $(DOCKER_TMP)/docker-build.yaml
	@$(DOCKER_COMPOSE) -f $< push $(ARGS)

.PHONY: shell
shell:
	@($(DOCKER) ps | $(GREP) -E "$(NAME)$$" $(NOOUT)) && \
		$(DOCKER) exec -it $(NAME) /bin/sh || \
		$(DOCKER) run --rm -it --entrypoint /bin/sh $(IMAGE):$(TAG)

.PHONY: logs
logs:
	@$(DOCKER_COMPOSE) logs -f $(ARGS)

.PHONY: up
up:
	@$(DOCKER_COMPOSE) up $(ARGS)

.PHONY: run
run:
	@$(DOCKER) run --rm -it ${IMAGE}:${TAG} $(ARGS)

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
$(CONTEXT)/.dockerignore: ;
endif

define DOCKER_BUILD_YAML
version: '3.7'
services:
  main:
    image: $${IMAGE}:$${TAG}
    build:
      context: $${CONTEXT}
      dockerfile: $${DOCKERFILE}
  major:
    extends: main
    image: $${IMAGE}:$${MAJOR}
  minor:
    extends: main
    image: $${IMAGE}:$${MAJOR}.$${MINOR}
  patch:
    extends: main
    image: $${IMAGE}:$${MAJOR}.$${MINOR}.$${PATCH}
endef
export DOCKER_BUILD_YAML

$(DOCKER_TMP)/docker-build.yaml:
	@$(MKDIR) -p $(@D)
	@echo "$$DOCKER_BUILD_YAML" > $@
