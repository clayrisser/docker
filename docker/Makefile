.POSIX:
ROOTDIR ?= $(eval ROOTDIR := $(shell git rev-parse --show-toplevel))$(ROOTDIR)
include $(ROOTDIR)/make.mk

.DEFAULT_GOAL := bake

# bake-block: target-specific variables go right above the target
BAKE_OUTPUT ?= docker
BAKE_ARGS ?= -f $(ROOTDIR)/docker/docker-bake.hcl --pull --provenance=false --allow=fs.read=..
ifeq (registry,$(BAKE_OUTPUT))
BAKE_ARGS += --set '*.platform=linux/amd64,linux/arm64' --push
else
BAKE_ARGS += --load
endif

.PHONY: bake bake/%
bake: $(ROOTDIR)/.dockerignore
	@[ "$(BAKE_OUTPUT)" != registry ] || case "$(GIT_COMMIT)" in *-dirty) echo "refusing to push from dirty tree (GIT_COMMIT=$(GIT_COMMIT)) — commit first" >&2; exit 1;; esac
	@$(BUILDX) bake $(BAKE_ARGS)
bake/%: $(ROOTDIR)/.dockerignore
	@[ "$(BAKE_OUTPUT)" != registry ] || case "$(GIT_COMMIT)" in *-dirty) echo "refusing to push from dirty tree (GIT_COMMIT=$(GIT_COMMIT)) — commit first" >&2; exit 1;; esac
	@$(BUILDX) bake $(BAKE_ARGS) $*

# compose lives at docker/compose.yaml; -p pins the project name so containers
# don't drift across cwd-based defaults.
COMPOSE_FILE := $(ROOTDIR)/docker/compose.yaml
COMPOSE_PROJECT := $(DOCKER_NAME)

.PHONY: up up/% down down/% logs logs/% ps ps/% shell
up:
	@$(COMPOSE) -f $(COMPOSE_FILE) -p $(COMPOSE_PROJECT) up -d --wait
up/%:
	@$(COMPOSE) -f $(COMPOSE_FILE) -p $(COMPOSE_PROJECT) --profile $* up -d --wait
down:
	-@$(COMPOSE) -f $(COMPOSE_FILE) -p $(COMPOSE_PROJECT) down --volumes --remove-orphans
down/%:
	-@$(COMPOSE) -f $(COMPOSE_FILE) -p $(COMPOSE_PROJECT) --profile $* down --volumes --remove-orphans
logs:
	@$(COMPOSE) -f $(COMPOSE_FILE) -p $(COMPOSE_PROJECT) logs -f
logs/%:
	@$(COMPOSE) -f $(COMPOSE_FILE) -p $(COMPOSE_PROJECT) --profile $* logs -f
ps:
	@$(COMPOSE) -f $(COMPOSE_FILE) -p $(COMPOSE_PROJECT) ps
ps/%:
	@$(COMPOSE) -f $(COMPOSE_FILE) -p $(COMPOSE_PROJECT) --profile $* ps

# Ad-hoc shell into the built image, no compose service required.
shell:
	@docker run --rm -it --entrypoint /bin/sh $(IMAGE):$(DOCKER_TAG)

# Apply kernel sysctl tunables listed in sysctl.list (host-level; needs sudo).
ifneq (,$(wildcard $(ROOTDIR)/docker/sysctl.list))
.PHONY: sysctl
sysctl:
	@while IFS='' read -r line || [ -n "$$line" ]; do \
		case "$$line" in ''|\#*) continue;; esac; \
		$(SUDO) sysctl -w "$$line"; \
	done < $(ROOTDIR)/docker/sysctl.list
endif

.PHONY: info
info:
	@echo BUILDX: $(BUILDX)
	@echo COMPOSE: $(COMPOSE)
	@echo IMAGE: $(IMAGE)
	@echo DOCKER_REGISTRY: $(DOCKER_REGISTRY)
	@echo DOCKER_NAME: $(DOCKER_NAME)
	@echo DOCKER_TAG: $(DOCKER_TAG)
	@echo GIT_COMMIT: $(GIT_COMMIT)
	@echo BAKE_OUTPUT: $(BAKE_OUTPUT)
	@echo BAKE_ARGS: $(BAKE_ARGS)
	@echo COMPOSE_FILE: $(COMPOSE_FILE)
	@echo COMPOSE_PROJECT: $(COMPOSE_PROJECT)
