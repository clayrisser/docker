# File: /main.mk
# Project: mkpm-docker
# File Created: 07-10-2021 16:58:49
# Author: Clay Risser
# -----
# Last Modified: 20-10-2022 03:01:02
# Modified By: Clay Risser
# -----
# Risser Labs LLC (c) Copyright 2021
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
export NAME ?= void
export TAG ?= latest
export VERSION ?= 0.0.1
export DOCKERFILE ?= $(CURDIR)/Dockerfile
export DOCKER_COMPOSE_YAML ?= $(CURDIR)/docker-compose.yaml
export DOCKER_COMPOSE_VERSION ?= 3.3
ifeq (,$(REGISTRY))
	export IMAGE := $(NAME)
else
	export IMAGE := $(REGISTRY)/$(NAME)
endif
export CONTAINER_NAME ?= $(shell $(ECHO) $(NAME) 2>$(NULL) | $(SED) "s|[\/-]|_|g" $(NOFAIL))
export MAJOR := $(shell $(ECHO) $(VERSION) 2>$(NULL) | $(CUT) -d. -f1 $(NOFAIL))
export MINOR := $(shell $(ECHO) $(VERSION) 2>$(NULL) | $(CUT) -d. -f2 $(NOFAIL))
export PATCH := $(shell $(ECHO) $(VERSION) 2>$(NULL) | $(CUT) -d. -f3 $(NOFAIL))

export DOCKER_FLAVOR ?= podman
export YQ ?= $(shell (yq | grep -q '\--output-format') && echo yq -o json || echo yq)
export PODMAN_COMPOSE_TRANSFORM_POLICY ?= identity

_DEFAULT_PODMAN_COMPOSE := $(call ternary,podman-compose --transform_policy=$(PODMAN_COMPOSE_TRANSFORM_POLICY),podman-compose --transform_policy=$(PODMAN_COMPOSE_TRANSFORM_POLICY),podman-compose)
ifeq ($(DOCKER_FLAVOR),docker)
export DOCKER_COMPOSE ?= $(call ternary,docker -v $(NOOUT) && \
	docker-compose -v,docker-compose,$(_DEFAULT_PODMAN_COMPOSE))
ifeq ($(findstring podman-compose,$(DOCKER_COMPOSE)),podman-compose)
DOCKER_COMPOSE := $(call ternary,podman -v $(NOOUT) && \
	podman-compose -v,$(DOCKER_COMPOSE),docker-compose)
endif
else
export DOCKER_COMPOSE ?= $(call ternary,podman -v $(NOOUT) && \
	podman-compose -v,$(_DEFAULT_PODMAN_COMPOSE),docker-compose)
ifeq ($(findstring docker-compose,$(DOCKER_COMPOSE)),docker-compose)
DOCKER_COMPOSE := $(call ternary,docker -v $(NOOUT) && \
	docker-compose -v,$(DOCKER_COMPOSE),$(_DEFAULT_PODMAN_COMPOSE))
endif
endif

export SYSCTL ?= $(call ternary,sysctl -V,sysctl,$(TRUE))
export DOCKER_FLAVOR := podman
ifeq ($(findstring docker-compose,$(DOCKER_COMPOSE)),docker-compose)
	DOCKER_FLAVOR := docker
	export DOCKER ?= docker
	_SUDO_TARGET := $(call ternary,$(DOCKER) ps,,sudo)
ifneq (,$(_SUDO_TARGET))
	DOCKER := $(SUDO) $(DOCKER)
	DOCKER_COMPOSE := $(SUDO) $(DOCKER_COMPOSE)
endif
else
	export DOCKER ?= podman
	_SYSCTL_TARGET := sysctl
	export PODMAN_COMPOSE ?= $(DOCKER_COMPOSE)
	export PODMAN ?= $(DOCKER)
endif

DOCKER_TMP := $(MKPM_TMP)/docker

.PHONY: build
build: $(DOCKER_TMP)/docker-build.yaml $(CONTEXT)/.dockerignore $(_SUDO_TARGET) $(DOCKER_BUILD_DEPENDENCIES)
	@$(DOCKER_COMPOSE) -f $< build $(ARGS) main
	@$(MAKE) -s tag

.PHONY: tag
tag: $(_SUDO_TARGET) $(DOCKER_TAG_DEPENDENCIES)
	@$(DOCKER) tag ${IMAGE}:${TAG} ${IMAGE}:${MAJOR}
	@$(DOCKER) tag ${IMAGE}:${TAG} ${IMAGE}:${MAJOR}.${MINOR}
	@$(DOCKER) tag ${IMAGE}:${TAG} ${IMAGE}:${MAJOR}.${MINOR}.${PATCH}

.PHONY: tags
tags: $(_SUDO_TARGET) $(DOCKER_TAGS_DEPENDENCIES)
	@echo ${IMAGE}:${TAG}
	@echo ${IMAGE}:${MAJOR}
	@echo ${IMAGE}:${MAJOR}.${MINOR}
	@echo ${IMAGE}:${MAJOR}.${MINOR}.${PATCH}

.PHONY: pull
pull: $(DOCKER_TMP)/docker-build.yaml $(_SUDO_TARGET) $(DOCKER_PULL_DEPENDENCIES)
	@$(DOCKER_COMPOSE) -f $< pull $(ARGS)

.PHONY: push
push: $(DOCKER_TMP)/docker-build.yaml $(DOCKER_PUSH_DEPENDENCIES)
	@$(DOCKER_COMPOSE) -f $< push $(ARGS)

.PHONY: shell
shell: $(_SUDO_TARGET) $(DOCKER_SHELL_DEPENDENCIES)
	@($(DOCKER) ps | $(GREP) -E "$(NAME)$$" $(NOOUT)) && \
		$(DOCKER) exec -it $(NAME) /bin/sh || \
		$(DOCKER) run --rm -it --entrypoint /bin/sh $(IMAGE):$(TAG)

.PHONY: logs
logs: $(_SUDO_TARGET) $(DOCKER_LOGS_DEPENDENCIES)
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_YAML) logs -f $(ARGS)

.PHONY: up ~up
~up: $(_SUDO_TARGET) $(_SYSCTL_TARGET)
	@$(MAKE) -s up ARGS="-d $(ARGS)"
up: $(_SUDO_TARGET) $(_SYSCTL_TARGET) $(DOCKER_UP_DEPENDENCIES) $(DOCKER_RUNTIME_DEPENDENCIES)
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_YAML) up $(ARGS)

.PHONY: run ~run
~run:
	@$(MAKE) -s run ARGS="-d $(ARGS)"
run: $(_SUDO_TARGET) $(_SYSCTL_TARGET) $(DOCKER_RUN_DEPENDENCIES) $(DOCKER_RUNTIME_DEPENDENCIES)
	@$(DOCKER) run --rm -it ${IMAGE}:${TAG} $(ARGS)

.PHONY: stop
stop: $(_SUDO_TARGET) $(DOCKER_STOP_DEPENDENCIES)
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_YAML) stop $(ARGS)

.PHONY: down
down: $(_SUDO_TARGET) $(DOCKER_DOWN_DEPENDENCIES)
ifeq ($(DOCKER_FLAVOR),docker)
	-@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_YAML) down -v --remove-orphans
else
	-@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_YAML) down
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
version: '$(DOCKER_COMPOSE_VERSION)'
services:
  main:
    image: $${IMAGE}:$${TAG}
    build:
      context: $${CONTEXT}
      dockerfile: $${DOCKERFILE}
  major:
    image: $${IMAGE}:$${MAJOR}
    build:
      context: $${CONTEXT}
      dockerfile: $${DOCKERFILE}
  minor:
    image: $${IMAGE}:$${MAJOR}.$${MINOR}
    build:
      context: $${CONTEXT}
      dockerfile: $${DOCKERFILE}
  patch:
    image: $${IMAGE}:$${MAJOR}.$${MINOR}.$${PATCH}
    build:
      context: $${CONTEXT}
      dockerfile: $${DOCKERFILE}
endef
export DOCKER_BUILD_YAML

$(DOCKER_TMP)/docker-build.yaml:
	@$(MKDIR) -p $(@D)
	@$(ECHO) "$$DOCKER_BUILD_YAML" > $@

export DOCKER_SERVICES :=
ifneq (,$(wildcard $(DOCKER_COMPOSE_YAML)))
ifneq ($(AUTOCALCULATE_DOCKER_SERVICES),0)
ifneq ($(YQ),true)
DOCKER_SERVICES := $(shell $(CAT) $(DOCKER_COMPOSE_YAML) | $(YQ) | \
	$(JQ) '.services' | $(JQ) -r 'keys[] | select (.!=null)' $(NOFAIL))
.PHONY: $(DOCKER_SERVICES)
$(DOCKER_SERVICES): $(DOCKER_RUNTIME_DEPENDENCIES)
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_YAML) up $(ARGS) $@
endif
endif
endif

.PHONY: %-d
%-d:
	@$(MAKE) -s $(subst -d,,$@) ARGS="-d"
