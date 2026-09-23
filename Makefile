.PHONY: help up down test test-integration migrate lint kind-up kind-down

help:       ## Muestra esta ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-16s\033[0m %s\n", $$1, $$2}'

up:         ## Levanta api + worker + postgres + redis + sqs (ElasticMQ) con Docker Compose
	docker compose up --build

down:       ## Para y elimina los contenedores locales
	docker compose down

migrate:    ## Aplica las migraciones de Alembic contra DATABASE_URL (fuera de Docker)
	cd apps/api && alembic upgrade head

test:       ## Ejecuta los tests unitarios de api y worker (no requieren Docker)
	cd apps/api && pytest --ignore=tests/integration && cd ../worker && pytest

test-integration: ## Ejecuta los tests de integración (Postgres + Redis reales vía testcontainers)
	cd apps/api && pytest tests/integration -m integration

lint:       ## Ejecuta los checks de pre-commit sobre todo el repo
	pre-commit run --all-files

kind-up:    ## Crea el cluster local
	kind create cluster --name linkly --config deploy/kind-config.yaml

kind-down:  ## Elimina el cluster local
	kind delete cluster --name linkly
