# File: /docker/Makefile
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

include $(MKPM)/mkpm
include $(MKPM)/gnu

export NAME := mkpm-docker
export VERSION := 0.0.1
export CONTEXT := context

include ../main.mk

.PHONY: info
info:
	@echo YAML2JSON: $(YAML2JSON)
	@echo DOCKER_FLAVOR: $(DOCKER_FLAVOR)
	@echo BUILDX: $(BUILDX)
	@echo DOCKER: $(DOCKER)
	@echo DOCKER_COMPOSE: $(DOCKER_COMPOSE)
	@echo PODMAN: $(PODMAN)
	@echo PODMAN_COMPOSE: $(PODMAN_COMPOSE)
	@echo DOCKER_SERVICES: $(DOCKER_SERVICES)
	@echo DOCKER_BUILD_YAML: $(DOCKER_BUILD_YAML)
	@echo DOCKER_COMPOSE_YAML: $(DOCKER_COMPOSE_YAML)
	@echo DOCKER_COMPOSE_VERSION: $(DOCKER_COMPOSE_VERSION)
	@echo DOCKERFILE: $(DOCKERFILE)
	@echo CONTEXT: $(CONTEXT)
	@echo REGISTRY: $(REGISTRY)
	@echo NAME: $(NAME)
	@echo TAG: $(TAG)
	@echo VERSION: $(VERSION)
	@echo IMAGE: $(IMAGE)
	@echo CONTAINER_NAME: $(CONTAINER_NAME)
	@echo PROJECT_NAME: $(PROJECT_NAME)
	@echo MAJOR: $(MAJOR)
	@echo MINOR: $(MINOR)
	@echo PATCH: $(PATCH)
	@echo GIT_COMMIT: $(GIT_COMMIT)
