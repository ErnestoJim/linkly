.PHONY: help up down test test-integration migrate lint \
        kind-up kind-down kind-ingress kind-deploy kind-images

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

kind-up:    ## Crea el cluster local (3 nodos: control-plane + 2 workers)
	kind create cluster --name linkly --config deploy/kind-config.yaml

kind-down:  ## Elimina el cluster local
	kind delete cluster --name linkly

kind-ingress: ## Instala ingress-nginx, anclado al control-plane (ver deploy/kind-config.yaml)
	helm upgrade --install ingress-nginx ingress-nginx \
		--repo https://kubernetes.github.io/ingress-nginx -n ingress-nginx --create-namespace \
		--set controller.hostPort.enabled=true \
		--set controller.service.type=NodePort \
		--set-string controller.nodeSelector.ingress-ready=true \
		--set controller.tolerations[0].key=node-role.kubernetes.io/control-plane \
		--set controller.tolerations[0].operator=Exists \
		--set controller.tolerations[0].effect=NoSchedule \
		--wait --timeout 3m

kind-images: ## Construye las imágenes y las carga en el cluster kind (tag :kind)
	docker build -t linkly-api:kind apps/api
	docker build -t linkly-worker:kind apps/worker
	kind load docker-image linkly-api:kind linkly-worker:kind --name linkly

kind-deploy: ## Despliega el chart en kind con Postgres/Redis/SQS en el propio cluster
	helm dependency build deploy/helm/linkly
	helm upgrade --install linkly deploy/helm/linkly \
		-f deploy/helm/linkly/values-local.yaml -n linkly --create-namespace \
		--set api.image.repository=linkly-api --set api.image.tag=kind \
		--set worker.image.repository=linkly-worker --set worker.image.tag=kind \
		--wait --timeout 5m
