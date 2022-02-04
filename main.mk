# File: /main.mk
# Project: mkpm-docker
# File Created: 07-10-2021 16:58:49
# Author: Clay Risser
# -----
# Last Modified: 04-02-2022 12:06:29
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
export CONTAINER_NAME ?= $(shell $(ECHO) $(NAME) 2>$(NULL) | $(SED) "s|[\/-]|_|g" $(NOFAIL))
export MAJOR := $(shell $(ECHO) $(VERSION) 2>$(NULL) | $(CUT) -d. -f1 $(NOFAIL))
export MINOR := $(shell $(ECHO) $(VERSION) 2>$(NULL) | $(CUT) -d. -f2 $(NOFAIL))
export PATCH := $(shell $(ECHO) $(VERSION) 2>$(NULL) | $(CUT) -d. -f3 $(NOFAIL))

export YQ ?= $(shell (yq | grep -q '\-\-output\-format') && echo yq -o json || echo yq)
export PODMAN_COMPOSE_TRANSFORM_POLICY ?= identity
export DOCKER_COMPOSE ?= $(call ternary,podman -v $(NOOUT) && \
	podman-compose -v,podman-compose --transform_policy=$(PODMAN_COMPOSE_TRANSFORM_POLICY),docker-compose)
ifeq ($(DOCKER_COMPOSE),docker-compose)
DOCKER_COMPOSE := $(call ternary,docker -v $(NOOUT) && \
	docker-compose -v,docker-compose,podman-compose)
endif
export SYSCTL ?= $(call ternary,sysctl -V,sysctl,$(TRUE))
export DOCKER_FLAVOR := podman
ifeq ($(findstring docker-compose,$(DOCKER_COMPOSE)),docker-compose)
	DOCKER_FLAVOR := docker
	export DOCKER ?= docker
	_SUDO_TARGET := $(call ternary,$(DOCKER) ps,,sudo)
ifneq (,$(_SUDO_TARGET))
	DOCKER := $(SUDO) -E $(DOCKER)
	DOCKER_COMPOSE := $(SUDO) -E $(DOCKER_COMPOSE)
endif
else
	export DOCKER ?= podman
	_SYSCTL_TARGET := sysctl
	export PODMAN_COMPOSE ?= $(DOCKER_COMPOSE)
	export PODMAN ?= $(DOCKER)
endif

DOCKER_TMP := $(MKPM_TMP)/docker

.PHONY: build
build: $(DOCKER_TMP)/docker-build.yaml $(CONTEXT)/.dockerignore $(_SUDO_TARGET)
	@$(DOCKER_COMPOSE) -f $< build $(ARGS) main
	@$(MAKE) -s tag

.PHONY: tag
tag: $(_SUDO_TARGET)
	@$(DOCKER) tag ${IMAGE}:${TAG} ${IMAGE}:${MAJOR}
	@$(DOCKER) tag ${IMAGE}:${TAG} ${IMAGE}:${MAJOR}.${MINOR}
	@$(DOCKER) tag ${IMAGE}:${TAG} ${IMAGE}:${MAJOR}.${MINOR}.${PATCH}

.PHONY: tags
tags: $(_SUDO_TARGET)
	@echo ${IMAGE}:${TAG}
	@echo ${IMAGE}:${MAJOR}
	@echo ${IMAGE}:${MAJOR}.${MINOR}
	@echo ${IMAGE}:${MAJOR}.${MINOR}.${PATCH}

.PHONY: pull
pull: $(DOCKER_TMP)/docker-build.yaml $(_SUDO_TARGET)
	@$(DOCKER_COMPOSE) -f $< pull $(ARGS)

.PHONY: push
push: $(DOCKER_TMP)/docker-build.yaml
	@$(DOCKER_COMPOSE) -f $< push $(ARGS)

.PHONY: shell
shell: $(_SUDO_TARGET)
	@($(DOCKER) ps | $(GREP) -E "$(NAME)$$" $(NOOUT)) && \
		$(DOCKER) exec -it $(NAME) /bin/sh || \
		$(DOCKER) run --rm -it --entrypoint /bin/sh $(IMAGE):$(TAG)

.PHONY: logs
logs: $(_SUDO_TARGET)
	@$(DOCKER_COMPOSE) logs -f $(ARGS)

.PHONY: up ~up
~up: $(_SUDO_TARGET) $(_SYSCTL_TARGET)
	@$(MAKE) -s up ARGS="-d $(ARGS)"
up: $(_SUDO_TARGET) $(_SYSCTL_TARGET)
	@$(DOCKER_COMPOSE) up $(ARGS)

.PHONY: run
run: $(_SUDO_TARGET) $(_SYSCTL_TARGET)
	@$(DOCKER) run --rm -it ${IMAGE}:${TAG} $(ARGS)

.PHONY: stop
stop: $(_SUDO_TARGET)
	@$(DOCKER_COMPOSE) stop $(ARGS)

.PHONY: down
down: $(_SUDO_TARGET)
ifeq ($(DOCKER_FLAVOR),docker)
	-@$(DOCKER_COMPOSE) down -v --remove-orphans
else
	-@$(DOCKER_COMPOSE) down
endif
	-@$(DOCKER) volume prune -f
	-@$(DOCKER) network prune -f

ifneq (,$(wildcard $(CURDIR)/sysctl.list))
SYSCTL_LIST := $(shell [ "$(shell $(CAT) $(CURDIR)/sysctl.list | \
	$(SED) 's|^\s*\#.*$$||g' | \
	$(SED) 's|^\s*$$||g' | \
	$(SED) '/^$$/d')" = "" ] || echo 1)
endif
ifneq (,$(SYSCTL_LIST))
.PHONY: sysctl
sysctl: sudo
	$(WHILE) IFS='' $(READ) -r LINE || [ -n "$$LINE" ]; $(DO) \
		$(SUDO) $(SYSCTL) -w "$$LINE"; \
	$(DONE) < $(CURDIR)/sysctl.list
else
sysctl: ;
endif

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
	@$(ECHO) "$$DOCKER_BUILD_YAML" > $@

ifneq ($(AUTOCALCULATE_DOCKER_SERVICES),0)
ifneq ($(YQ),true)
DOCKER_SERVICES := $(shell $(CAT) docker-compose.yaml | $(YQ) | $(JQ) '.services' | $(JQ) -r 'keys[]')
.PHONY: $(DOCKER_SERVICES)
$(DOCKER_SERVICES):
	@$(DOCKER_COMPOSE) up $(ARGS) $@
endif
endif

.PHONY: %-d
%-d:
	@$(MAKE) -s $(subst -d,,$@) ARGS="-d"
