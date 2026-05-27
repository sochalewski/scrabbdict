SHELL := /bin/bash

.DEFAULT_GOAL := help

HOOK := $(shell git rev-parse --git-path hooks/pre-commit 2>/dev/null)
.PHONY: help init install-mise install-dependencies install-hooks format format-lint format-lint-strict

help:
	@echo "Available targets:"
	@echo "  make init               Install local tooling and pre-commit hook"
	@echo "  make format             Format Swift sources"
	@echo "  make format-lint        Check Swift formatting without rewriting files"
	@echo "  make format-lint-strict Check Swift formatting and fail on violations"

init: install-mise install-dependencies install-hooks

install-mise:
	@if ! command -v brew >/dev/null 2>&1; then \
		echo "Homebrew is required to install mise."; \
		exit 1; \
	fi
	@if command -v mise >/dev/null 2>&1; then \
		echo "mise already installed"; \
	else \
		brew install mise; \
	fi

install-dependencies:
	@mise trust .mise.toml
	@mise install

install-hooks:
	@mkdir -p .git/hooks
	@printf '%s\n' \
		'#!/usr/bin/env bash' \
		'set -euo pipefail' \
		'' \
		'cd "$$(git rev-parse --show-toplevel)"' \
		'' \
		'if ! command -v mise >/dev/null 2>&1; then' \
		'  echo "mise not found. Run make init." >&2' \
		'  exit 1' \
		'fi' \
		'' \
		'mise install --quiet' \
		'mise exec -- git-format-staged --formatter "mise exec -- swiftformat stdin --stdin-path '"'"'{}'"'"'" "*.swift"' \
		> "$(HOOK)"
	@chmod +x "$(HOOK)"
	@echo "Installed $(HOOK)"

format:
	@mise run format

format-lint:
	@mise run format-lint

format-lint-strict:
	@mise run format-lint-strict