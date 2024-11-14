# File: /main.mk
# Project: docker
# File Created: 16-10-2023 06:10:54
# Author: Clay Risser
# -----
# BitSpur (c) Copyright 2021 - 2023
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
export REGISTRY ?= docker.io/library
export NAME ?= void
export TAG ?= latest
export VERSION ?= 0.0.1
export DOCKERFILE ?= $(CURDIR)/Dockerfile
ifneq (,$(wildcard $(CURDIR)/docker-compose.yaml))
DOCKER_COMPOSE_YAML ?= $(CURDIR)/docker-compose.yaml
endif
ifneq (,$(wildcard $(CURDIR)/docker-compose.yml))
DOCKER_COMPOSE_YAML ?= $(CURDIR)/docker-compose.yml
endif
ifneq (,$(wildcard $(CURDIR)/compose.yaml))
DOCKER_COMPOSE_YAML ?= $(CURDIR)/compose.yaml
endif
ifneq (,$(wildcard $(CURDIR)/compose.yml))
DOCKER_COMPOSE_YAML ?= $(CURDIR)/compose.yml
endif
export PROJECT_NAME ?= $(NAME)
ifeq (,$(DOCKER_BUILD_YAML))
ifneq (,$(wildcard $(CURDIR)/docker-build.yaml))
DOCKER_BUILD_YAML ?= $(CURDIR)/docker-build.yaml
endif
ifneq (,$(wildcard $(CURDIR)/docker-build.yml))
DOCKER_BUILD_YAML ?= $(CURDIR)/docker-build.yml
endif
endif
_DOCKER_TMP := $(MKPM_TMP)/docker
export IMAGE := $(REGISTRY)/$(NAME)
export CONTAINER_NAME ?= $(shell $(ECHO) $(NAME) 2>$(NULL) | $(SED) "s|[\/-]|_|g" $(NOFAIL))
TAG_SEMVER ?= 1
TAG_SEMVER_MAJOR ?= 1
TAG_SEMVER_MINOR ?= 1
TAG_SEMVER_PATCH ?= 1
TAG_GIT_COMMIT ?= 1
_DOTS := $(shell $(ECHO) $(VERSION) 2>$(NULL) | $(TR) -cd '.' $(NOFAIL))
ifeq (.,$(_DOTS))
_VALID_SEMVER := 1
export MINOR := $(shell $(ECHO) $(VERSION) 2>$(NULL) | $(CUT) -d. -f2 $(NOFAIL))
endif
ifeq (..,$(_DOTS))
_VALID_SEMVER := 1
export MINOR := $(shell $(ECHO) $(VERSION) 2>$(NULL) | $(CUT) -d. -f2 $(NOFAIL))
export PATCH := $(shell $(ECHO) $(VERSION) 2>$(NULL) | $(CUT) -d. -f3 $(NOFAIL))
endif
ifeq (1,$(_VALID_SEMVER))
export MAJOR := $(shell $(ECHO) $(VERSION) 2>$(NULL) | $(CUT) -d. -f1 $(NOFAIL))
else
export MAJOR := $(VERSION)
endif
export GIT_COMMIT ?= $(shell $(GIT) describe --tags --always --dirty 2>$(NULL))

DOCKER_FLAVOR ?= docker
PODMAN_COMPOSE_TRANSFORM_POLICY ?= identity
YAML2JSON ?= $(shell $(WHICH) yq 2>&1 >/dev/null && \
	((yq --version | $(GREP) -q "github.com/mikefarah/yq") && echo 'yq -o json' || echo yq) || \
	echo 'ruby -ryaml -rjson -e "puts JSON.pretty_generate(YAML.load(ARGF))"')

_PODMAN_COMPOSE := $(call ternary,podman-compose \
	--transform_policy=$(PODMAN_COMPOSE_TRANSFORM_POLICY),podman-compose \
	--transform_policy=$(PODMAN_COMPOSE_TRANSFORM_POLICY),podman-compose)
_DOCKER_COMPOSE := $(call ternary,which docker-compose $(NOOUT),docker-compose,docker compose)
ifeq ($(DOCKER_FLAVOR),podman)
DOCKER_COMPOSE ?= $(_PODMAN_COMPOSE)
else
DOCKER_COMPOSE ?= $(_DOCKER_COMPOSE)
endif
PODMAN_COMPOSE ?= $(_PODMAN_COMPOSE)
PODMAN ?= podman
BUILDX ?= $(call ternary,$(DOCKER) buildx $(NOOUT),$(DOCKER) buildx,docker-buildx)

SYSCTL ?= $(call ternary,sysctl -V,sysctl,$(TRUE))
DOCKER_FLAVOR := docker
ifeq ($(findstring podman-compose,$(DOCKER_COMPOSE)),podman-compose)
	DOCKER_FLAVOR := podman
	DOCKER ?= podman
	_SYSCTL_TARGET := sysctl
else
	DOCKER ?= docker
ifneq (darwin,$(PLATFORM))
	_DOCKER_SUDO := $(call ternary,$(DOCKER) ps,,sudo)
endif
ifneq (,$(_DOCKER_SUDO))
	DOCKER := $(SUDO) $(DOCKER)
	DOCKER_COMPOSE := $(SUDO) $(DOCKER_COMPOSE)
endif
endif

.PHONY: tag
tag: $(_SUDO_TARGET) $(DOCKER_TAG_TARGETS)
ifeq (1,$(TAG_SEMVER))
ifeq (1,$(TAG_SEMVER_MAJOR))
ifneq (,$(MAJOR))
ifneq ($(TAG),$(MAJOR))
	@$(DOCKER) tag $(IMAGE):$(TAG) $(IMAGE):$(MAJOR)
	@$(ECHO) tagged $(IMAGE):$(MAJOR)
endif
endif
endif
ifeq (1,$(TAG_SEMVER_MINOR))
ifneq (,$(MINOR))
	@$(DOCKER) tag $(IMAGE):$(TAG) $(IMAGE):$(MAJOR).$(MINOR)
	@$(ECHO) tagged $(IMAGE):$(MAJOR).$(MINOR)
endif
endif
ifeq (1,$(TAG_SEMVER_PATCH))
ifneq (,$(PATCH))
	@$(DOCKER) tag $(IMAGE):$(TAG) $(IMAGE):$(MAJOR).$(MINOR).$(PATCH)
	@$(ECHO) tagged $(IMAGE):$(MAJOR).$(MINOR).$(PATCH)
endif
endif
endif
ifeq (1,$(TAG_GIT_COMMIT))
ifneq (,$(GIT_COMMIT))
	@$(DOCKER) tag $(IMAGE):$(TAG) $(IMAGE):$(GIT_COMMIT)
	@$(ECHO) tagged $(IMAGE):$(GIT_COMMIT)
endif
endif

.PHONY: tags
tags: $(_SUDO_TARGET) $(DOCKER_TAGS_TARGETS)
	@$(ECHO) $(IMAGE):$(TAG)
ifeq (1,$(TAG_SEMVER))
ifeq (1,$(TAG_SEMVER_MAJOR))
ifneq (,$(MAJOR))
ifneq ($(TAG),$(MAJOR))
	@$(ECHO) $(IMAGE):$(MAJOR)
endif
endif
endif
ifeq (1,$(TAG_SEMVER_MINOR))
ifneq (,$(MINOR))
	@$(ECHO) $(IMAGE):$(MAJOR).$(MINOR)
endif
endif
ifeq (1,$(TAG_SEMVER_PATCH))
ifneq (,$(PATCH))
	@$(ECHO) $(IMAGE):$(MAJOR).$(MINOR).$(PATCH)
endif
endif
endif
ifeq (1,$(TAG_GIT_COMMIT))
ifneq (,$(GIT_COMMIT))
	@$(ECHO) $(IMAGE):$(GIT_COMMIT)
endif
endif

.PHONY: build
build: _docker-build-yaml $(CONTEXT)/.dockerignore $(_DOCKER_SUDO) $(DOCKER_BUILD_TARGETS)
	@$(DOCKER_COMPOSE) -f $(_DOCKER_TMP)/docker-build.yaml build $(_ARGS) $(DOCKER_BUILD_ARGS) main
ifeq (,$(wildcard Mkpmfile))
	@$(MAKE) -s tag
else
	@$(MKPM_MAKE) tag
endif

.PHONY: pull
pull: _docker-build-yaml $(_SUDO_TARGET) $(DOCKER_PULL_TARGETS)
	@$(DOCKER_COMPOSE) -f $(_DOCKER_TMP)/docker-build.yaml pull $(_ARGS) $(DOCKER_PULL_ARGS)

.PHONY: push
push: _docker-build-yaml $(_SUDO_TARGET) $(DOCKER_PUSH_TARGETS)
	@$(DOCKER_COMPOSE) -f $(_DOCKER_TMP)/docker-build.yaml push $(_ARGS) $(DOCKER_PUSH_ARGS)

.PHONY: shell
shell: $(_SUDO_TARGET) $(DOCKER_SHELL_TARGETS)
	@($(DOCKER) ps | $(GREP) -E "$(NAME)$$" $(NOOUT)) && \
		$(DOCKER) exec -it $(NAME) /bin/sh || \
		$(DOCKER) run --rm -it --entrypoint /bin/sh $(IMAGE):$(TAG)

.PHONY: logs
logs: $(_SUDO_TARGET) $(DOCKER_LOGS_TARGETS)
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_YAML) logs -f $(_ARGS) $(DOCKER_LOGS_ARGS)

.PHONY: up
up: $(_SUDO_TARGET) $(_SYSCTL_TARGET) $(DOCKER_UP_TARGETS) $(DOCKER_RUNTIME_TARGETS)
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_YAML) -p $(PROJECT_NAME) up $(_ARGS) $(DOCKER_UP_ARGS)

.PHONY: run
run: $(_SUDO_TARGET) $(_SYSCTL_TARGET) $(DOCKER_RUN_TARGETS) $(DOCKER_RUNTIME_TARGETS)
	@$(DOCKER) run --rm -it $(IMAGE):$(TAG) $(_ARGS) $(DOCKER_RUN_ARGS)

.PHONY: stop
stop: $(_SUDO_TARGET) $(DOCKER_STOP_TARGETS)
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_YAML) stop $(_ARGS) $(DOCKER_STOP_ARGS)

.PHONY: down
down: $(_SUDO_TARGET) $(DOCKER_DOWN_TARGETS)
ifeq ($(DOCKER_FLAVOR),docker)
	-@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_YAML) down --volumes --remove-orphans $(_ARGS) $(DOCKER_DOWN_ARGS)
else
	-@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_YAML) down $(_ARGS) $(DOCKER_DOWN_ARGS)
	-@$(DOCKER) network prune -f
	-@$(DOCKER) volume prune -f
endif

BAKE_ARGS ?= --pull --push --provenance=false
.PHONY: bake bake/%
bake: $(CONTEXT)/.dockerignore
	@$(DOCKER) buildx bake --print 2>/dev/null | $(JQ) -r \
		'. as $$root | .target | to_entries[] | select(.value["cache-from"] != null) | {key: .key, tags: .value["cache-from"][0]} | "\(.key)\t\(.tags)"' | \
		$(AWK) -F'\t' '{ printf "  %s:\n    image: %s\n", $$1, $$2 }' | \
		($(ECHO) "services:" && $(CAT)) | $(DOCKER_COMPOSE) -f- pull
	@$(BUILDX) bake $(BAKE_ARGS)
bake/%:
	@if [ -n "$(shell $(DOCKER) buildx bake --print 2>/dev/null | $(JQ) -r '.target["$*"]["cache-from"][0] // empty')" ]; then \
		$(DOCKER) buildx bake --print 2>/dev/null | $(JQ) -r '.target["$*"]["cache-from"][0]' | $(XARGS) $(DOCKER) pull; \
	fi
	@$(BUILDX) bake $(BAKE_ARGS) $*

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

define _DOCKER_BUILD_YAML_BASE
services:
  main:
    image: $${IMAGE}:$${TAG}
    build:
      context: $${CONTEXT}
      dockerfile: $${DOCKERFILE}
endef
ifeq (1,$(TAG_SEMVER))
ifeq (1,$(TAG_SEMVER_PATCH))
ifneq (,$(PATCH))
define _DOCKER_BUILD_YAML_PATCH
  patch:
    image: $${IMAGE}:$${MAJOR}.$${MINOR}.$${PATCH}
    build:
      context: $${CONTEXT}
      dockerfile: $${DOCKERFILE}
endef
endif
endif
ifeq (1,$(TAG_SEMVER_MINOR))
ifneq (,$(MINOR))
define _DOCKER_BUILD_YAML_MINOR
  minor:
    image: $${IMAGE}:$${MAJOR}.$${MINOR}
    build:
      context: $${CONTEXT}
      dockerfile: $${DOCKERFILE}
endef
endif
endif
ifeq (1,$(TAG_SEMVER_MAJOR))
ifneq (,$(MAJOR))
define _DOCKER_BUILD_YAML_MAJOR
  major:
    image: $${IMAGE}:$${MAJOR}
    build:
      context: $${CONTEXT}
      dockerfile: $${DOCKERFILE}
endef
endif
endif
endif
ifeq (1,$(TAG_GIT_COMMIT))
ifneq (,$(GIT_COMMIT))
define _DOCKER_BUILD_YAML_GIT_COMMIT
  git-commit:
    image: $${IMAGE}:$${GIT_COMMIT}
    build:
      context: $${CONTEXT}
      dockerfile: $${DOCKERFILE}
endef
endif
endif
define _DOCKER_BUILD_YAML
$(_DOCKER_BUILD_YAML_BASE)
$(_DOCKER_BUILD_YAML_PATCH)
$(_DOCKER_BUILD_YAML_MINOR)
$(_DOCKER_BUILD_YAML_MAJOR)
$(_DOCKER_BUILD_YAML_GIT_COMMIT)
endef
export _DOCKER_BUILD_YAML

.PHONY: _docker-build-yaml
_docker-build-yaml:
	@$(MKDIR) -p $(_DOCKER_TMP)
ifeq (,$(wildcard $(DOCKER_BUILD_YAML)))
	@$(ECHO) "$$_DOCKER_BUILD_YAML" > $(_DOCKER_TMP)/docker-build.yaml
else
	@$(CP) $(DOCKER_BUILD_YAML) $(_DOCKER_TMP)/docker-build.yaml
endif

DOCKER_SERVICES :=
ifneq (,$(wildcard $(DOCKER_COMPOSE_YAML)))
ifneq ($(AUTOCALCULATE_DOCKER_SERVICES),0)
DOCKER_SERVICES := $(shell $(CAT) $(DOCKER_COMPOSE_YAML) | $(YAML2JSON) | \
	$(JQ) '.services' | $(JQ) -r 'keys[] | select (.!=null)' $(NOFAIL))
.PHONY: $(DOCKER_SERVICES)
$(DOCKER_SERVICES): $(DOCKER_RUNTIME_TARGETS)
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_YAML) up $(_ARGS) $(DOCKER_UP_ARGS) $@
endif
endif

.PHONY: %-d
%-d:
ifeq (,$(wildcard Mkpmfile))
	@$(MAKE) -s $* _ARGS="-d"
else
	@$(MKPM_MAKE) $* _ARGS="-d"
endif
