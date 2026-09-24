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
  bootstrap/     # Bucket S3 para el estado de Terraform (locking nativo, sin DynamoDB)
  github-oidc/   # OIDC provider + rol que asume GitHub Actions (sin access keys)
  modules/       # network, eks, data (RDS+SQS), iam (EKS Pod Identity)
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
```

SQS se simula en local con [ElasticMQ](https://github.com/softwaremill/elasticmq)
(`softwaremill/elasticmq-native`); la cola `linkly-clicks` y su DLQ
(`linkly-clicks-dlq`, `maxReceiveCount=5`) se declaran en
[`deploy/helm/linkly/files/elasticmq.conf`](deploy/helm/linkly/files/elasticmq.conf)
(el mismo archivo que usa el chart de Helm para `values-local.yaml`), así
que no hace falta ningún paso manual de setup.

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

## Kubernetes (kind)

Todo se prueba primero en [kind](https://kind.sigs.k8s.io/) antes que en
EKS: si funciona ahí, en EKS casi solo cambian los valores
(`values-dev.yaml` en vez de `values-local.yaml`).

```bash
make kind-up       # Cluster de 3 nodos (control-plane + 2 workers)
make kind-ingress   # Instala ingress-nginx anclado al control-plane
make kind-images    # Construye api/worker y las carga en el cluster (tag :kind)
make kind-deploy    # helm upgrade --install con values-local.yaml (Postgres/Redis/SQS en el cluster)
kubectl get pods -n linkly -w
```

`make kind-ingress` no es un `helm install` a pelo: sin
`controller.hostPort.enabled=true` + el `nodeSelector`/`tolerations` hacia
el control-plane, el controller podría acabar en un worker (que no tiene
los `extraPortMappings` de [`deploy/kind-config.yaml`](deploy/kind-config.yaml))
y `curl http://localhost` no llegaría a ningún sitio.

**Punto de control:**

```bash
curl -X POST http://localhost/api/links -H 'Content-Type: application/json' \
  -d '{"url":"https://github.com"}'
curl -i http://localhost/<code>   # 302 → https://github.com
```

**Pruebas de resiliencia** (documentadas aquí tal como pide la Fase 5):

- **Borra un pod de la API** (`kubectl delete pod -n linkly $(kubectl get pods -n linkly -l app.kubernetes.io/component=api -o jsonpath='{.items[0].metadata.name}')`): con 2 réplicas + `Service`, el resto de peticiones a `http://localhost/...` no deberían fallar — Kubernetes saca el pod del Service en cuanto deja de responder al `readinessProbe`. Verificado en esta máquina: 15 `POST /api/links` seguidos mientras se borraba un pod, **0 fallos** (todos `201`).
- **Para el worker** (`kubectl scale deploy linkly-worker -n linkly --replicas=0`): los clics se siguen aceptando (la API solo publica en SQS, no depende del worker para el 302) y se acumulan en la cola de ElasticMQ; al volver a escalar a 1, se procesan y aparecen en `/api/links/{code}/stats`. Verificado: con el worker en 0, `total_clicks` se queda fijo pese a más redirecciones; al volver a `--replicas=1`, sube de golpe reflejando todo lo acumulado.

### Qué incluye el chart (`deploy/helm/linkly`)

| Recurso | Detalle |
| --- | --- |
| Deployment API | 2 réplicas (o gestionadas por el HPA), `readinessProbe` en `/readyz`, `livenessProbe` en `/healthz` |
| Deployment worker | Sin Service, `terminationGracePeriodSeconds: 30` |
| Service + Ingress | Solo para la API |
| HorizontalPodAutoscaler | CPU 70 %, 2–6 réplicas (desactivado en `values-local.yaml`: kind no trae `metrics-server`) |
| PodDisruptionBudget | `minAvailable: 1` en la API |
| ServiceAccount | Uno por servicio (api, worker) |
| Job de migraciones | Hook `post-install,pre-upgrade` (**no** `pre-install`: con Postgres como subchart en el mismo release, `pre-install` corre antes de que Postgres exista siquiera — ver comentario en `migration-job.yaml`). Con `--wait`, Helm no devuelve el control hasta que termina, así que en la práctica sigue siendo "migra antes de que el pod de turno reciba tráfico" |
| ServiceMonitor | `serviceMonitor.enabled: false` por defecto; se activa en la Fase 9 |

Todos los contenedores propios del chart (api, worker, job de
migraciones) corren con `requests: {cpu: 50m, memory: 128Mi}`,
`limits: {memory: 256Mi}` y `securityContext: {runAsNonRoot: true,
readOnlyRootFilesystem: true, allowPrivilegeEscalation: false,
capabilities: {drop: ["ALL"]}}`.

`values.yaml` trae lo común; `values-local.yaml` añade Postgres/Redis
(subcharts de Bitnami, `helm dependency build` los descarga) y ElasticMQ
(plantillas propias, no hay chart oficial) dentro del cluster;
`values-dev.yaml`/`values-prod.yaml` apuntan a RDS/SQS reales en AWS (ver
abajo) — el `DATABASE_URL`/`SQS_QUEUE_URL` siguen siendo placeholders
(`REPLACE_ME`) hasta rellenarlos con los outputs de Terraform.

## Infraestructura AWS (Terraform)

> **Aviso de coste**: con todo levantado (EKS + nodos + RDS) el gasto
> ronda unos pocos dólares al día — solo el cluster EKS ya son
> ~0,10 $/h. Levántalo para trabajar o para la demo y **destrúyelo el
> mismo día** (`terraform destroy`).

`infra/modules` envuelve los módulos de la comunidad
(`terraform-aws-modules/{vpc,eks}/aws`) en los nuestros, como se hace en
empresas reales en vez de reinventar VPC/EKS desde cero:

| Módulo | Qué monta |
| --- | --- |
| `network` | VPC (`terraform-aws-modules/vpc/aws`), 2 AZs, subredes públicas (nodos) + privadas (solo RDS). **Sin NAT Gateway** — ver [ADR-0002](docs/adr/0002-no-nat-gateway.md) |
| `eks` | Cluster EKS (`terraform-aws-modules/eks/aws`), K8s 1.35 (la penúltima en soporte estándar — la más probada), endpoint público restringido a tu IP, node group spot (2×`t3.medium`/`t3a.medium`), addons `vpc-cni`/`coredns`/`kube-proxy`/`eks-pod-identity-agent` |
| `data` | RDS Postgres `db.t4g.micro` en subredes privadas (SG solo acepta tráfico desde los nodos), contraseña gestionada por AWS Secrets Manager; cola SQS `<env>-clicks` + su DLQ (`maxReceiveCount=5`) |
| `iam` | Dos roles vía **EKS Pod Identity** (sin claves de larga duración): uno para `linkly-worker` con `sqs:ReceiveMessage`/`sqs:DeleteMessage`, otro para `linkly-api` con `sqs:SendMessage` — asociados a esos ServiceAccounts exactos del chart de Helm |

### Uso

```bash
cd infra/bootstrap
terraform init && terraform apply   # una sola vez; anota el output bucket_name

# copia ese bucket_name en infra/envs/dev/backend.tf (reemplaza <ACCOUNT_ID>)
cd ../envs/dev
terraform init
terraform plan -out=tfplan -var 'allowed_public_access_cidrs=["<TU_IP>/32"]'
terraform apply tfplan

aws eks update-kubeconfig --name linkly-dev --region eu-west-1
kubectl get nodes

# ... demo (make kind-* no aplica aquí; despliega con values-dev.yaml
# una vez rellenados los placeholders de DATABASE_URL/SQS_QUEUE_URL) ...

terraform destroy   # siempre, al terminar
```

`infra/envs/dev/backend.tf` lleva el bucket en texto plano a propósito
— los bloques `backend` de Terraform no admiten variables ni data
sources. `infra/bootstrap` no usa `region`/`state_bucket_name` fijos:
calcula el nombre del bucket con tu Account ID (`aws_caller_identity`)
para que sea único sin inventarse un sufijo.

No hay módulo de Terraform para Redis/ElastiCache todavía — es un hueco
conocido, `REDIS_URL` en `values-dev.yaml`/`values-prod.yaml` se queda
como placeholder.

### GitHub Actions sin access keys (OIDC)

`infra/github-oidc` monta el trust entre GitHub Actions y AWS por OIDC
— ningún workflow guarda una access key de AWS. Se corre una vez, a
mano, después de `infra/bootstrap`:

```bash
cd infra/github-oidc
terraform init
terraform apply -var 'state_bucket_name=<bucket de infra/bootstrap>'
```

Copia el `role_arn` que devuelve a un **repository variable** (no
secret — el ARN de un rol no es sensible) llamado
`AWS_GITHUB_ACTIONS_ROLE_ARN`, en *Settings → Secrets and variables →
Actions → Variables*. A partir de ahí, [`terraform.yml`](.github/workflows/terraform.yml):

- En cada PR que toque `infra/`: hace `terraform plan` para `dev` y
  `prod` y lo publica (actualizándolo, no duplicándolo) como comentario
  en el PR.
- El `apply` **solo** se dispara a mano desde la pestaña Actions
  (`workflow_dispatch`, eligiendo entorno y, opcionalmente, tu IP para
  `allowed_public_access_cidrs`) — nunca por un push o PR normal, así
  no se crea infraestructura con coste por accidente.

La trust policy del rol acepta dos patrones de `sub`, no solo el del
enunciado original: uno para el `plan` en pull requests
(`repo:<owner>/linkly:pull_request`, sin importar la rama) y otro para
el `apply` manual (`repo:<owner>/linkly:ref:refs/heads/main`) — con
solo el segundo, el plan en PRs nunca habría podido autenticarse.

Los permisos del rol son deliberadamente amplios (`ec2:*`, `eks:*`,
`rds:*`, `sqs:*`, `iam:*` sobre `*`, más S3 acotado al bucket de
estado) — acotarlos al mínimo real es trabajo de iterar contra
`AccessDenied`, no algo razonable de adivinar de antemano para una
demo. Es el primer sitio a estrechar para un uso serio.

## CI/CD

**[`ci.yml`](.github/workflows/ci.yml)** corre en cada PR y en cada push a
`main`:

| Job | Qué valida |
| --- | --- |
| `lint-test` (matrix api/worker) | `ruff`, `mypy`, `pytest` |
| `api-integration` | tests de integración (Postgres/Redis reales) |
| `terraform-check` | `terraform fmt -check`, `terraform validate` (sin backend) y `tflint` sobre `infra/` |
| `helm-lint` | `helm lint` + `helm template` validado con `kubeconform`, para las 4 combinaciones de values |
| `kind-smoke-test` | levanta un cluster kind real, despliega el chart y hace `curl` contra `/api/links` y la redirección |
| `build-scan` (matrix api/worker) | construye ambas imágenes y las escanea con Trivy — falla si hay `CRITICAL` |
| `pre-commit` | los mismos hooks que corren localmente |

**[`release.yml`](.github/workflows/release.yml)** corre en cada push a
`main`: construye y sube ambas imágenes a GHCR etiquetadas con el SHA corto
del commit (`ghcr.io/<owner>/linkly-api:3f2a1bc`, nunca `latest`, con caché
de GitHub Actions), y luego actualiza `deploy/helm/linkly/values-dev.yaml`
con ese tag y hace commit directo a `main` (con `[skip ci]` para no
disparar el pipeline en bucle) — así Argo CD detecta el cambio y sincroniza
dev automáticamente (Fase 8).

**[`terraform.yml`](.github/workflows/terraform.yml)**: `plan` en cada
PR que toca `infra/` (comentado en el PR) + `apply` manual por
`workflow_dispatch`. Se autentica contra AWS por OIDC, sin access keys
— ver [la sección de arriba](#github-actions-sin-access-keys-oidc).

Cada workflow declara `permissions:` mínimos por job, y todas las actions
de terceros están fijadas a un commit SHA (no a un tag).
