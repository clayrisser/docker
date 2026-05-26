MAKEFLAGS += --no-print-directory

# Local Make state (markers, generated env.mk, etc.) lives under MAKEDIR.
# No natural language host (this repo is a Docker / Make-only project), so
# use the generic .make/ at repo root.
MAKEDIR := $(ROOTDIR)/.make
MARKERS := $(MAKEDIR)/markers

-include $(MAKEDIR)/env.mk

# Recipes spawn fresh non-interactive shells that don't source ~/.zshrc, so
# the asdf shim dir isn't on PATH unless we add it here. Honour ASDF_DATA_DIR
# if the user overrides it (XDG-style).
export PATH := $(or $(ASDF_DATA_DIR),$(HOME)/.asdf)/shims:$(PATH)

# Tool defaults — overridable via env. Plain ?= for literal-string defaults.
GIT ?= git
SHFMT ?= shfmt
CLOC ?= cloc
BATS ?= bats

# Tool defaults that come from $(shell …) — lazy-eval so the shell only runs
# once, on first reference, and the result is cached.
SUDO ?= $(eval SUDO := $(shell command -v sudo >/dev/null 2>&1 && echo sudo))$(SUDO)
PKG_INSTALL ?= $(eval PKG_INSTALL := $(or \
	$(shell command -v brew >/dev/null 2>&1 && echo 'brew install'), \
	$(shell command -v apt-get >/dev/null 2>&1 && echo '$(SUDO) apt-get update && $(SUDO) apt-get install -y'), \
	$(shell command -v dnf >/dev/null 2>&1 && echo '$(SUDO) dnf install -y'), \
	$(shell command -v pacman >/dev/null 2>&1 && echo '$(SUDO) pacman -S --noconfirm'), \
	echo "no supported package manager" >&2;false))$(PKG_INSTALL)
BUILDX ?= $(eval BUILDX := $(shell command -v docker-buildx >/dev/null 2>&1 && echo docker-buildx || echo 'docker buildx'))$(BUILDX)
COMPOSE ?= $(eval COMPOSE := $(shell command -v docker-compose >/dev/null 2>&1 && echo docker-compose || echo 'docker compose'))$(COMPOSE)

# Project-wide exports — bake.hcl / compose.yaml read these as shell env.
# This repo is the mkpm-docker package itself; the demo image lives at
# docker/Dockerfile and ships under docker.io/library/mkpm-docker.
export DOCKER_REGISTRY ?= docker.io/library
export DOCKER_NAME ?= mkpm-docker
export DOCKER_TAG ?= latest
export GIT_COMMIT ?= $(eval GIT_COMMIT := $(shell $(GIT) -C $(ROOTDIR) describe --tags --always --dirty 2>/dev/null))$(GIT_COMMIT)
export IMAGE ?= $(DOCKER_REGISTRY)/$(DOCKER_NAME)

.PHONY: FORCE
FORCE:

# .env → $(MAKEDIR)/env.mk: any change to .env triggers regeneration before
# targets run (Make's -include auto-rebuilds the included file if it has a
# rule). .env itself bootstraps from .env.example on first use.
$(ROOTDIR)/.env: $(ROOTDIR)/.env.example
	@[ -f $@ ] && cp $@ $@.bak; cp $< $@
$(MAKEDIR)/env.mk: $(ROOTDIR)/.env
	@mkdir -p $(@D)
	@awk '/^[[:space:]]*(#|$$)/&&!m{next}'\
	'm{if(/"$$/){sub(/"$$/,"");print;print"endef";print"export "k;m=0}else print;next}'\
	'/^[A-Za-z_][A-Za-z0-9_]*=/{k=substr($$0,1,index($$0,"=")-1);v=substr($$0,index($$0,"=")+1);'\
	'if(v~/^"/&&v!~/"$$/){printf"define %s ?=\n",k;sub(/^"/,"",v);print v;m=1}else{gsub(/^"|"$$/,"",v);'\
	'if(v)printf"define %s ?=\n%s\nendef\nexport %s\n",k,v,k;else printf"%s ?=\nexport %s\n",k,k}}' $< > $@

# .dockerignore mirrors .gitignore so the two stay in sync.
$(ROOTDIR)/.dockerignore: $(ROOTDIR)/.gitignore
	@cp "$<" "$@"
