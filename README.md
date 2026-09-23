# linkly

URL shortener con API (FastAPI) y worker asíncrono, desplegado en EKS vía
Helm/Argo CD, con infraestructura en Terraform.

## Estructura

```
apps/
  api/       # FastAPI: crea/resuelve links
  worker/    # Procesa jobs async (p. ej. eventos de click) desde SQS
deploy/
  helm/linkly/   # Chart de la aplicación
  argocd/        # Definiciones de Argo CD (dev/prod)
infra/
  bootstrap/     # Bucket S3 + tabla DynamoDB para el estado de Terraform
  modules/       # network, eks, rds, sqs, iam
  envs/          # dev, prod
observability/   # Dashboards y reglas de alerta
loadtest/        # Scripts de carga (k6)
docs/
  adr/           # Architecture Decision Records
```

## API

| Método | Ruta | Qué hace |
| --- | --- | --- |
| POST | `/api/links` | Recibe `{"url": "..."}` y devuelve `{"code": "...", "short_url": "..."}` |
| GET | `/{code}` | Redirige con 302 (cache Redis, con fallback a Postgres) |
| GET | `/api/links/{code}/stats` | Total de clics y clics por día |
| GET | `/healthz` | Liveness |
| GET | `/readyz` | Readiness: comprueba Postgres y Redis |
| GET | `/metrics` | Métricas Prometheus |

La redirección publica un evento en SQS (`{"code", "ts", "user_agent", "referer"}`)
sin esperar a que se procese; el worker hace long polling, inserta los clics
en Postgres en lote y borra los mensajes solo tras persistirlos.

## Imágenes Docker

`apps/api/Dockerfile` y `apps/worker/Dockerfile` usan build multi-stage:

1. **`builder`**: instala [`uv`](https://docs.astral.sh/uv/) y resuelve las
   dependencias desde `pyproject.toml` + `uv.lock` (`uv export --no-dev` →
   `pip install --prefix=/install`).
2. **Imagen final**: parte de `python:3.12-slim` limpia, copia solo lo
   instalado (`/usr/local`) y el código — sin compiladores ni `uv` — y
   corre como usuario sin privilegios (`uid 10001`), no como root.

Esto mantiene la imagen final pequeña y reduce la superficie de ataque: no
hay toolchain de compilación ni credenciales de build en la imagen que se
despliega, y un proceso comprometido no corre como root dentro del
contenedor. La API, además, aplica las migraciones de Alembic al arrancar
(`docker-entrypoint.sh`) antes de levantar `uvicorn`.

## Desarrollo local

```bash
make up               # Levanta api + worker + postgres + redis + sqs (ElasticMQ)
make test              # Tests unitarios de api y worker (no requieren Docker)
make test-integration   # Tests de integración con Postgres/Redis reales (testcontainers, requiere Docker)
make migrate            # Aplica las migraciones de Alembic contra DATABASE_URL (fuera de Docker)
make kind-up             # Crea un cluster local con kind para probar el chart de Helm
```

SQS se simula en local con [ElasticMQ](https://github.com/softwaremill/elasticmq)
(`softwaremill/elasticmq-native`); la cola `linkly-clicks` y su DLQ
(`linkly-clicks-dlq`, `maxReceiveCount=5`) se declaran en
[`deploy/elasticmq.conf`](deploy/elasticmq.conf), así que no hace falta
ningún paso manual de setup.

Copia `apps/api/.env.example` / `apps/worker/.env.example` a `.env` para
correr cada servicio fuera de Docker Compose. Toda la configuración se lee
de variables de entorno (`DATABASE_URL`, `REDIS_URL`, `SQS_QUEUE_URL`,
`AWS_ENDPOINT_URL`) vía `pydantic-settings` — nada hardcodeado.

**Punto de control**: con `make up` corriendo, deberías poder crear un
link y verlo redirigir:

```bash
curl -X POST localhost:8000/api/links -H 'content-type: application/json' \
  -d '{"url": "https://anthropic.com"}'
# {"code": "aB3xK9", "short_url": "http://localhost:8000/aB3xK9"}

curl -i localhost:8000/aB3xK9   # 302 → https://anthropic.com
curl localhost:8000/api/links/aB3xK9/stats
# {"code": "aB3xK9", "total_clicks": 1, "clicks_by_day": [...]}
```

El primer `GET /{code}` cachea el destino en Redis y publica un evento en
SQS; el worker lo consume y lo inserta en Postgres, así que el contador de
`total_clicks` puede tardar un instante en reflejar el último clic.

Ver `make help` para todos los comandos disponibles.

## CI/CD

**[`ci.yml`](.github/workflows/ci.yml)** corre en cada PR y en cada push a
`main`:

| Job | Qué valida |
| --- | --- |
| `lint-test` (matrix api/worker) | `ruff`, `mypy`, `pytest` |
| `api-integration` | tests de integración (Postgres/Redis reales) |
| `terraform-check` | `terraform fmt -check`, `terraform validate` (sin backend) y `tflint` sobre `infra/` |
| `helm-lint` | `helm lint` + `helm template` validado con `kubeconform` |
| `build-scan` (matrix api/worker) | construye ambas imágenes y las escanea con Trivy — falla si hay `CRITICAL` |
| `pre-commit` | los mismos hooks que corren localmente |

**[`release.yml`](.github/workflows/release.yml)** corre en cada push a
`main`: construye y sube ambas imágenes a GHCR etiquetadas con el SHA corto
del commit (`ghcr.io/<owner>/linkly-api:3f2a1bc`, nunca `latest`, con caché
de GitHub Actions), y luego actualiza `deploy/helm/linkly/values-dev.yaml`
con ese tag y hace commit directo a `main` (con `[skip ci]` para no
disparar el pipeline en bucle) — así Argo CD detecta el cambio y sincroniza
dev automáticamente (Fase 8).

Cada workflow declara `permissions:` mínimos por job, y todas las actions
de terceros están fijadas a un commit SHA (no a un tag).
