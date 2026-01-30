# Makefile for kubectl-migrate

# Version and Build Info
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
COMMIT ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE ?= $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

# Binary Info
BINARY_NAME = kubectl-migrate
MAIN_PACKAGE = .
BUILD_DIR = bin

# Go parameters
GOCMD = go
GOBUILD = $(GOCMD) build
GOCLEAN = $(GOCMD) clean
GOTEST = $(GOCMD) test
GOGET = $(GOCMD) get
GOMOD = $(GOCMD) mod

# Linker flags to inject version info
LDFLAGS = -ldflags "\
	-X 'github.com/konveyor-ecosystem/kubectl-migrate/internal/buildinfo.Version=$(VERSION)' \
	-X 'github.com/konveyor-ecosystem/kubectl-migrate/internal/buildinfo.Commit=$(COMMIT)' \
	-X 'github.com/konveyor-ecosystem/kubectl-migrate/internal/buildinfo.BuildDate=$(BUILD_DATE)'"

# Platforms for cross-compilation
PLATFORMS = linux/amd64 linux/arm64 darwin/amd64 darwin/arm64

.PHONY: all build build-all clean test-unit deps install check fmt vet lint resources-deploy resources-destroy resources-validate help

all: build

help: ## Display this help message
	@echo "kubectl-migrate Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make <target>"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  %-15s %s\n", $$1, $$2 } /^##@/ { printf "\n%s\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

build: ## Build the binary for the current platform
	@echo "Building $(BINARY_NAME) version $(VERSION)..."
	@mkdir -p $(BUILD_DIR)
	$(GOBUILD) $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME) $(MAIN_PACKAGE)
	@echo "Build complete: $(BUILD_DIR)/$(BINARY_NAME)"

build-all: clean ## Build binaries for all platforms
	@echo "Building for all platforms..."
	@$(foreach platform,$(PLATFORMS), \
		$(eval OS = $(word 1,$(subst /, ,$(platform)))) \
		$(eval ARCH = $(word 2,$(subst /, ,$(platform)))) \
		$(eval OUTPUT = $(BUILD_DIR)/$(BINARY_NAME)-$(OS)-$(ARCH)) \
		$(if $(filter windows,$(OS)),$(eval OUTPUT := $(OUTPUT).exe)) \
		echo "Building for $(OS)/$(ARCH)..." && \
		GOOS=$(OS) GOARCH=$(ARCH) $(GOBUILD) $(LDFLAGS) -o $(OUTPUT) $(MAIN_PACKAGE) && \
		echo "  ✓ $(OUTPUT)" || exit 1; \
	)
	@echo "All builds complete!"

clean: ## Remove built binaries
	@echo "Cleaning..."
	$(GOCLEAN)
	rm -rf $(BUILD_DIR)
	@echo "Clean complete!"

test-unit: ## Run golang unit tests
	@echo "Running tests..."
	$(GOTEST) -v ./...

deps: ## Download dependencies
	@echo "Downloading dependencies..."
	$(GOMOD) download
	$(GOMOD) tidy
	@echo "Dependencies updated!"

install: ## Build and install the binary to $GOPATH/bin
	@echo "Installing $(BINARY_NAME) to $(GOPATH)/bin..."
	$(GOBUILD) $(LDFLAGS) -o $(GOPATH)/bin/$(BINARY_NAME) $(MAIN_PACKAGE)
	@echo "Installation complete!"
	@echo "You can now use: kubectl migrate <command>"

fmt: ## Format Go code
	@echo "Formatting code..."
	$(GOCMD) fmt ./...

vet: ## Run go vet
	@echo "Running go vet..."
	$(GOCMD) vet ./...

lint: ## Run golangci-lint (requires golangci-lint to be installed)
	@echo "Running golangci-lint..."
	golangci-lint run

check: fmt vet test-unit ## Run fmt, vet, and test-unit
	@echo "All checks passed!"

###############################################################################

# Dummy target to prevent "No rule to make target" errors when passing app names as arguments
%:
	@:

resources-deploy: ## Deploy sample application(s) to cluster (optionally specify app names)
	@if [ "$(filter-out $@,$(MAKECMDGOALS))" ]; then \
		for app in $(filter-out $@,$(MAKECMDGOALS)); do \
			echo "Deploying sample application: $$app..."; \
			if [ -d "sample-resources/$$app" ]; then \
				if [ -f "sample-resources/$$app/deploy.sh" ]; then \
					(cd "sample-resources/$$app" && ./deploy.sh); \
					echo "Application $$app deployed successfully!"; \
				else \
					echo "Error: deploy.sh not found in sample-resources/$$app"; \
					exit 1; \
				fi; \
			else \
				echo "Error: Directory sample-resources/$$app does not exist"; \
				exit 1; \
			fi; \
		done \
	else \
		echo "Deploying all sample applications..."; \
		for dir in sample-resources/*/; do \
			if [ -f "$$dir/deploy.sh" ]; then \
				echo "Deploying $$dir..."; \
				(cd "$$dir" && ./deploy.sh); \
			fi \
		done; \
		echo "All applications deployed successfully!"; \
	fi

resources-destroy: ## Remove sample application(s) from cluster (optionally specify app names)
	@if [ "$(filter-out $@,$(MAKECMDGOALS))" ]; then \
		for app in $(filter-out $@,$(MAKECMDGOALS)); do \
			echo "Destroying sample application: $$app..."; \
			if [ -d "sample-resources/$$app" ]; then \
				if [ -f "sample-resources/$$app/destroy.sh" ]; then \
					(cd "sample-resources/$$app" && ./destroy.sh); \
					echo "Application $$app destroyed successfully!"; \
				else \
					echo "Error: destroy.sh not found in sample-resources/$$app"; \
					exit 1; \
				fi; \
			else \
				echo "Error: Directory sample-resources/$$app does not exist"; \
				exit 1; \
			fi; \
		done \
	else \
		echo "Destroying all sample applications..."; \
		for dir in sample-resources/*/; do \
			if [ -f "$$dir/destroy.sh" ]; then \
				echo "Destroying $$dir..."; \
				(cd "$$dir" && ./destroy.sh); \
			fi \
		done; \
		echo "All applications destroyed successfully!"; \

resources-validate: ## Validate sample application(s) in cluster (optionally specify app names)
	@if [ "$(filter-out $@,$(MAKECMDGOALS))" ]; then \
		failed=""; \
		for app in $(filter-out $@,$(MAKECMDGOALS)); do \
			echo "Validating sample application: $$app..."; \
			if [ -d "sample-resources/$$app" ]; then \
				if [ -f "sample-resources/$$app/validate.sh" ]; then \
					if (cd "sample-resources/$$app" && ./validate.sh); then \
						echo "Application $$app validated successfully!"; \
					else \
						echo "Application $$app validation FAILED!"; \
						failed="$$failed $$app"; \
					fi; \
				else \
					echo "Error: validate.sh not found in sample-resources/$$app"; \
					failed="$$failed $$app"; \
				fi; \
			else \
				echo "Error: Directory sample-resources/$$app does not exist"; \
				failed="$$failed $$app"; \
			fi; \
		done; \
		if [ -n "$$failed" ]; then \
			echo ""; \
			echo "Validation FAILED for the following applications:$$failed"; \
			exit 1; \
		else \
			echo "All applications validated successfully!"; \
		fi \
	else \
		echo "Validating all sample applications..."; \
		failed=""; \
		for dir in sample-resources/*/; do \
			if [ -f "$$dir/validate.sh" ]; then \
				app=$$(basename "$$dir"); \
				echo "Validating $$app..."; \
				if (cd "$$dir" && ./validate.sh); then \
					echo "Application $$app validated successfully!"; \
				else \
					echo "Application $$app validation FAILED!"; \
					failed="$$failed $$app"; \
				fi; \
			fi \
		done; \
		if [ -n "$$failed" ]; then \
			echo ""; \
			echo "Validation FAILED for the following applications:$$failed"; \
			exit 1; \
		else \
			echo "All applications validated successfully!"; \
		fi \
	fi
