# TODO: write the Dockerfile for the FastAPI app
#
# Steps to consider:
# 1. FROM python:3.12-slim
# 2. WORKDIR
# 3. Copy requirements.txt separately and install it (layer caching!)
# 4. Only then copy the rest of the code (app/)
# 5. Don't run as root - add a user
# 6. EXPOSE the port
# 7. CMD with uvicorn
#
# Bonus: HEALTHCHECK hitting /health

FROM python:3.14-slim AS builder

WORKDIR /app

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

COPY pyproject.toml pyproject.toml

COPY uv.lock uv.lock

RUN uv sync --python /usr/local/bin/python3

FROM python:3.14-slim

WORKDIR /app

COPY --from=builder /app/.venv /app/.venv

COPY app ./app

EXPOSE 8000

CMD ["/app/.venv/bin/uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]