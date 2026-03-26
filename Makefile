# Pokemon Full-Stack Application - Makefile
#
# Unified task runner for building and deploying the Pokemon app.
# Works on Linux and macOS natively, and on Windows via WSL or GNU Make.
#
# Usage:
#   make help            Show available targets
#   make build           Build both frontend and backend
#   make deploy          Deploy to production server
#   make setup-server    Provision a new server
#

# ─── Configuration ───────────────────────────────────────────────────────────
SHELL := /bin/bash

# Override these via environment or command line:
#   make deploy SERVER=192.168.1.100 SSH_KEY=~/.ssh/id_rsa
SERVER       ?=
SSH_PORT     ?= 22
SSH_KEY      ?=
DEPLOY_USER  ?= testrigor
API_URL      ?= http://$(SERVER):21051

FRONTEND_DIR := $(CURDIR)
BACKEND_DIR  := $(CURDIR)/../pokemon-backend

# ─── Default Target ──────────────────────────────────────────────────────────
.DEFAULT_GOAL := help

# ─── Help ────────────────────────────────────────────────────────────────────
.PHONY: help
help: ## Show available targets
	@echo ""
	@echo "Pokemon App - Available Commands"
	@echo "================================"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Configuration (override with environment variables):"
	@echo "  SERVER=$(SERVER)"
	@echo "  SSH_PORT=$(SSH_PORT)"
	@echo "  SSH_KEY=$(SSH_KEY)"
	@echo "  DEPLOY_USER=$(DEPLOY_USER)"
	@echo "  API_URL=$(API_URL)"
	@echo ""
	@echo "Example:"
	@echo "  make deploy SERVER=192.168.1.100 SSH_KEY=~/.ssh/id_rsa"
	@echo ""

# ─── Build Targets ───────────────────────────────────────────────────────────
.PHONY: build-frontend
build-frontend: ## Build the React frontend
	@echo "=== Building Frontend ==="
	cd $(FRONTEND_DIR) && bash build.sh --api-url "$(API_URL)"

.PHONY: build-backend
build-backend: ## Build the Node.js backend
	@echo "=== Building Backend ==="
	cd $(BACKEND_DIR) && bash build.sh

.PHONY: build
build: build-frontend build-backend ## Build both frontend and backend

# ─── Deploy Targets ──────────────────────────────────────────────────────────
.PHONY: deploy
deploy: ## Deploy both frontend and backend to production
	@if [ -z "$(SERVER)" ]; then echo "ERROR: SERVER is required. Usage: make deploy SERVER=<host> SSH_KEY=<path>"; exit 1; fi
	@if [ -z "$(SSH_KEY)" ]; then echo "ERROR: SSH_KEY is required. Usage: make deploy SERVER=<host> SSH_KEY=<path>"; exit 1; fi
	cd $(FRONTEND_DIR) && bash deploy.sh \
		--server "$(SERVER)" \
		--port "$(SSH_PORT)" \
		--key "$(SSH_KEY)" \
		--user "$(DEPLOY_USER)" \
		--api-url "$(API_URL)"

.PHONY: deploy-frontend
deploy-frontend: ## Deploy only the frontend
	@if [ -z "$(SERVER)" ]; then echo "ERROR: SERVER is required."; exit 1; fi
	@if [ -z "$(SSH_KEY)" ]; then echo "ERROR: SSH_KEY is required."; exit 1; fi
	cd $(FRONTEND_DIR) && bash deploy.sh \
		--server "$(SERVER)" \
		--port "$(SSH_PORT)" \
		--key "$(SSH_KEY)" \
		--user "$(DEPLOY_USER)" \
		--api-url "$(API_URL)" \
		--frontend-only

.PHONY: deploy-backend
deploy-backend: ## Deploy only the backend
	@if [ -z "$(SERVER)" ]; then echo "ERROR: SERVER is required."; exit 1; fi
	@if [ -z "$(SSH_KEY)" ]; then echo "ERROR: SSH_KEY is required."; exit 1; fi
	cd $(FRONTEND_DIR) && bash deploy.sh \
		--server "$(SERVER)" \
		--port "$(SSH_PORT)" \
		--key "$(SSH_KEY)" \
		--user "$(DEPLOY_USER)" \
		--backend-only

# ─── Server Setup ────────────────────────────────────────────────────────────
.PHONY: setup-server
setup-server: ## Provision a new Linux server (run on target server)
	@echo "=== Server Setup ==="
	@echo "This must be run as root on the target server."
	sudo bash $(FRONTEND_DIR)/setup-server.sh

# ─── Clean Targets ───────────────────────────────────────────────────────────
.PHONY: clean-frontend
clean-frontend: ## Remove frontend build artifacts
	@echo "Cleaning frontend build..."
	rm -rf $(FRONTEND_DIR)/build

.PHONY: clean-backend
clean-backend: ## Remove backend build artifacts
	@echo "Cleaning backend build..."
	rm -rf $(BACKEND_DIR)/dist

.PHONY: clean
clean: clean-frontend clean-backend ## Remove all build artifacts
	@echo "All build artifacts cleaned."

# ─── Development Targets ─────────────────────────────────────────────────────
.PHONY: install
install: ## Install dependencies for both projects
	@echo "=== Installing Frontend Dependencies ==="
	cd $(FRONTEND_DIR) && npm install
	@echo ""
	@echo "=== Installing Backend Dependencies ==="
	cd $(BACKEND_DIR) && npm install

.PHONY: dev-frontend
dev-frontend: ## Start frontend development server
	cd $(FRONTEND_DIR) && npm start

.PHONY: dev-backend
dev-backend: ## Start backend development server
	cd $(BACKEND_DIR) && npm run dev
