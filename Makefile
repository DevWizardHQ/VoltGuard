SHELL := /bin/bash
APP_NAME := VoltGuard
BUNDLE_ID := com.devwizardhq.voltguard
CONFIG ?= release
DIST := dist
APP := $(DIST)/$(APP_NAME).app
VERSION ?= $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo 0.0.0)
BUILD ?= $(shell git rev-list --count HEAD 2>/dev/null || echo 1)

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.PHONY: build
build: ## Build the release binary for this machine
	swift build -c $(CONFIG)

.PHONY: test
test: ## Run the test suite
	swift test

.PHONY: test-core
test-core: ## Run non-UI tests (works without Xcode)
	VOLTGUARD_CORE_ONLY=1 swift test --scratch-path .build-core

.PHONY: selftest
selftest: ## Exercise IOKit, SQLite and the engine on this machine
	swift build -c $(CONFIG) --product voltguard-selftest
	"$$(swift build -c $(CONFIG) --product voltguard-selftest --show-bin-path)/voltguard-selftest"

.PHONY: lint
lint: ## Check formatting
	swift format lint --recursive --strict Sources Tests

.PHONY: format
format: ## Apply formatting
	swift format --in-place --recursive Sources Tests

.PHONY: icon
icon: ## Regenerate the app icon and installer background
	swift run voltguard-iconforge
	swift Scripts/make-dmg-background.swift

.PHONY: icon-states
icon-states: ## Render a contact sheet of the menu bar icon states
	swift run voltguard-iconforge --states dist/icon-states.png

.PHONY: bundle
bundle: ## Assemble VoltGuard.app
	VERSION=$(VERSION) BUILD=$(BUILD) CONFIG=$(CONFIG) ./Scripts/bundle.sh

.PHONY: run
run: ## Build and launch the app bundle
	CONFIG=debug $(MAKE) bundle
	open $(APP)

.PHONY: sign
sign: ## Codesign the bundle inside-out
	./Scripts/sign.sh $(APP)

.PHONY: dmg
dmg: ## Build a distributable disk image
	VERSION=$(VERSION) ./Scripts/dmg.sh $(APP)

.PHONY: notarize
notarize: ## Notarize and staple the disk image
	./Scripts/notarize.sh $(DIST)/$(APP_NAME).dmg

.PHONY: appcast
appcast: ## Generate the EdDSA-signed Sparkle appcast
	./Scripts/appcast.sh

.PHONY: release
release: build bundle sign dmg notarize appcast ## Full release pipeline

.PHONY: clean
clean: ## Remove build output
	rm -rf .build .build-core $(DIST)
