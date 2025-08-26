# Makefile
GOPATH:=$(shell go env GOPATH)
GOBIN:=$(GOPATH)/bin
GOCMD:=go
GOBUILD:=$(GOCMD) build
GOCLEAN:=$(GOCMD) clean
GOTEST:=$(GOCMD) test
GOGET:=$(GOCMD) get
GOMOD:=$(GOCMD) mod

# Docker設定
DOCKER_COMPOSE:=docker compose -f deploy/docker/compose.yml

# バイナリ名
AUTH_BINARY:=auth-service
CATALOG_BINARY:=catalog-service
INSTANCE_BINARY:=instance-service
WORKER_BINARY:=instance-worker
CLI_BINARY:=moinctl

# ビルドフラグ
LDFLAGS:=-ldflags "-s -w"

.PHONY: all help setup clean test build

all: help

help: ## ヘルプを表示
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## 開発環境をセットアップ
	@echo "Installing dependencies..."
	$(GOMOD) download
	@echo "Installing tools..."
	@which golangci-lint > /dev/null || go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@which wire > /dev/null || go install github.com/google/wire/cmd/wire@latest
	@which ent > /dev/null || go install entgo.io/ent/cmd/ent@latest
	@echo "Creating config files..."
	@cp configs/auth-service.example.yaml configs/auth-service.yaml 2>/dev/null || true
	@cp configs/catalog-service.example.yaml configs/catalog-service.yaml 2>/dev/null || true
	@cp configs/instance-service.example.yaml configs/instance-service.yaml 2>/dev/null || true
	@echo "Setup complete!"

clean: ## ビルド成果物をクリーン
	@echo "Cleaning..."
	$(GOCLEAN)
	rm -rf bin/
	@echo "Clean complete!"

test: ## テストを実行
	@echo "Running tests..."
	$(GOTEST) -v -cover -race ./...

test-pkg: ## pkg配下のテストのみ実行
	@echo "Running pkg tests..."
	$(GOTEST) -v -cover -race ./pkg/...

test-integration: ## 統合テストを実行
	@echo "Running integration tests..."
	$(GOTEST) -v -cover ./test/integration/...

lint: ## Lintを実行
	@echo "Running linter..."
	golangci-lint run ./...

build: build-auth build-catalog build-instance build-worker build-cli ## 全てをビルド

build-auth: ## Auth Serviceをビルド
	@echo "Building $(AUTH_BINARY)..."
	$(GOBUILD) $(LDFLAGS) -o bin/$(AUTH_BINARY) ./cmd/auth-service

build-catalog: ## Catalog Serviceをビルド
	@echo "Building $(CATALOG_BINARY)..."
	$(GOBUILD) $(LDFLAGS) -o bin/$(CATALOG_BINARY) ./cmd/catalog-service

build-instance: ## Instance Serviceをビルド
	@echo "Building $(INSTANCE_BINARY)..."
	$(GOBUILD) $(LDFLAGS) -o bin/$(INSTANCE_BINARY) ./cmd/instance-service

build-worker: ## Instance Workerをビルド
	@echo "Building $(WORKER_BINARY)..."
	$(GOBUILD) $(LDFLAGS) -o bin/$(WORKER_BINARY) ./cmd/instance-worker

build-cli: ## CLIをビルド
	@echo "Building $(CLI_BINARY)..."
	$(GOBUILD) $(LDFLAGS) -o bin/$(CLI_BINARY) ./cmd/moinctl

run-auth: build-auth ## Auth Serviceを実行
	@echo "Starting $(AUTH_BINARY)..."
	./bin/$(AUTH_BINARY)

run-catalog: build-catalog ## Catalog Serviceを実行
	@echo "Starting $(CATALOG_BINARY)..."
	./bin/$(CATALOG_BINARY)

run-instance: build-instance ## Instance Serviceを実行
	@echo "Starting $(INSTANCE_BINARY)..."
	./bin/$(INSTANCE_BINARY)

run-worker: build-worker ## Instance Workerを実行
	@echo "Starting $(WORKER_BINARY)..."
	./bin/$(WORKER_BINARY)

docker-up: ## Docker環境を起動
	$(DOCKER_COMPOSE) up -d
	@echo "Waiting for services to be ready..."
	@sleep 5
	@echo "Docker services are running!"
	@echo "TiDB:     mysql://root@localhost:4000/"
	@echo "RabbitMQ: http://localhost:15672 (admin/admin)"
	@echo "Memcached: localhost:11211"

docker-down: ## Docker環境を停止
	$(DOCKER_COMPOSE) down

docker-logs: ## Dockerログを表示
	$(DOCKER_COMPOSE) logs -f

docker-ps: ## Docker環境の状態を表示
	$(DOCKER_COMPOSE) ps

docker-clean: docker-down ## Docker環境をクリーン
	$(DOCKER_COMPOSE) down -v
	@echo "Docker environment cleaned!"

# 開発用ターゲット
dev: docker-up ## 開発環境を起動
	@echo "Development environment is ready!"

.DEFAULT_GOAL := help
