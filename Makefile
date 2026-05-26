.POSIX:
export ROOTDIR ?= $(eval ROOTDIR := $(shell git rev-parse --show-toplevel))$(ROOTDIR)
include $(ROOTDIR)/make.mk

.DEFAULT_GOAL := build

.PHONY: sudo
sudo:
	@$(SUDO) true

.PHONY: prepare prepare/asdf prepare/cloc
prepare: sudo
	@command -v asdf >/dev/null 2>&1 || $(MAKE) prepare/asdf
	@command -v cloc >/dev/null 2>&1 || $(MAKE) prepare/cloc
	@awk '!/^#/ && NF {print $$1}' .tool-versions | \
		while read t; do asdf plugin add "$$t" 2>/dev/null || true; done
	@rcfile=$$(mktemp); \
		{ asdf install 2>&1; echo $$? >$$rcfile; } | grep --line-buffered -v 'is already installed' || true; \
		rc=$$(cat $$rcfile); rm -f $$rcfile; exit $$rc
prepare/asdf:
	@command -v brew >/dev/null 2>&1 && brew install asdf || { \
		o=$$(uname | tr A-Z a-z); a=$$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/'); \
		curl -fsSL "https://github.com/asdf-vm/asdf/releases/download/v0.18.0/asdf-v0.18.0-$$o-$$a.tar.gz" \
			| $(SUDO) tar -xz -C /usr/local/bin asdf; \
	}
prepare/cloc:
	@$(PKG_INSTALL) cloc

.PHONY: configure
configure:
	@for cmd in asdf $(CLOC) jq docker; do \
		command -v $$cmd >/dev/null 2>&1 || { echo "$$cmd is missing, run 'make prepare'"; exit 1; }; \
	done

.PHONY: docker docker/%
docker: FORCE
	@$(MAKE) -C docker
docker/%: FORCE
	@$(MAKE) -C docker $*

.PHONY: build
build: docker/bake

.PHONY: bake bake/%
bake: docker/bake
bake/%: FORCE
	@$(MAKE) -C docker bake/$*

.PHONY: up down logs ps
up: docker/up
down: docker/down
logs: docker/logs
ps: docker/ps

.PHONY: shell
shell: docker/shell

.PHONY: format
format: configure
	@command -v $(SHFMT) >/dev/null 2>&1 && $(SHFMT) -w $$($(GIT) ls-files '*.sh' '*.bats' 2>/dev/null) 2>/dev/null || true

.PHONY: lint
lint: configure
	@command -v $(SHFMT) >/dev/null 2>&1 && $(SHFMT) -d $$($(GIT) ls-files '*.sh' '*.bats' 2>/dev/null) 2>/dev/null || true

.PHONY: count
count:
	@$(CLOC) $$($(GIT) ls-files)

.PHONY: clean
clean:
	@rm -f $(ROOTDIR)/.dockerignore
	@rm -rf $(MAKEDIR)

.PHONY: purge
purge: clean
	@$(GIT) clean -fxd
