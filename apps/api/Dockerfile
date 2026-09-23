# Etapa 1: resuelve dependencias con uv, sin herramientas de compilación
# en la imagen final.
FROM python:3.12-slim AS builder
WORKDIR /build
RUN pip install --no-cache-dir uv
COPY pyproject.toml uv.lock ./
RUN uv export --no-dev --no-emit-project > requirements.txt && \
    pip install --no-cache-dir --prefix=/install -r requirements.txt

# Etapa 2: imagen final, mínima y sin root.
FROM python:3.12-slim
RUN useradd --uid 10001 --no-create-home appuser
WORKDIR /app
COPY --from=builder /install /usr/local
COPY app ./app
COPY alembic ./alembic
COPY alembic.ini ./
COPY docker-entrypoint.sh ./
RUN chmod +x docker-entrypoint.sh

USER 10001
EXPOSE 8000
ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
