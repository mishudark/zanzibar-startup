-include bazel.mk
.PHONY: help
.DEFAULT_GOAL := help
SHELL         := /usr/bin/env bash

help: ## Show this help message.
	@echo 'usage: make [target]'
	@echo
	@echo 'targets:'
	@egrep '^(.+)\:\ ##\ (.+)' ${MAKEFILE_LIST} | column -t -c 2 -s ':#'
