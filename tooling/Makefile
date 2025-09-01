# tooling/Makefile

# Directories
CMD_DIR   := ./cmd
REPO_ROOT := $(shell git rev-parse --show-toplevel 2>/dev/null)
DEST_DIR  ?= $(REPO_ROOT)/go-scripts

# Detect all subdirectories under ./cmd as programs
PROGRAMS := $(notdir $(wildcard $(CMD_DIR)/*))

# Build config
GOOS        ?= $(shell go env GOOS)
GOARCH      ?= $(shell go env GOARCH)
CGO_ENABLED ?= 0
VERSION     := $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
LDFLAGS     := -s -w -X main.version=$(VERSION)

.PHONY: all build clean print-vars
all: build

## Build all PROGRAMS directly into $(DEST_DIR)
build: $(PROGRAMS:%=$(DEST_DIR)/%)

# Pattern rule: build each cmd/<name> into DEST_DIR/<name>
# The order-only prerequisite '|' ensures DEST_DIR exists before building.
$(DEST_DIR)/%: $(CMD_DIR)/%/** go.mod | $(DEST_DIR)
	@echo ">> building $* ($(GOOS)/$(GOARCH)) -> $@"
	GOOS=$(GOOS) GOARCH=$(GOARCH) CGO_ENABLED=$(CGO_ENABLED) \
		go build -trimpath -ldflags '$(LDFLAGS)' -o $@ ./cmd/$*

# Ensure DEST_DIR exists
$(DEST_DIR):
	@mkdir -p $@

clean:
	@echo ">> cleaning $(DEST_DIR)"
	@rm -f $(DEST_DIR)/*

print-vars:
	@echo PROGRAMS=$(PROGRAMS)
	@echo REPO_ROOT=$(REPO_ROOT)
	@echo DEST_DIR=$(DEST_DIR)
	@echo GOOS=$(GOOS)
	@echo GOARCH=$(GOARCH)
	@echo VERSION=$(VERSION)
