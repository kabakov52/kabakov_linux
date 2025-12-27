FROM python:3.10-slim AS builder

ENV VENV_PATH=/opt/venv \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update \
 && apt-get install -y --no-install-recommends gcc \
 && rm -rf /var/lib/apt/lists/*

RUN python -m venv "${VENV_PATH}" \
 && "${VENV_PATH}/bin/pip" install --upgrade pip

# Сначала кладём исходники, чтобы install . видел пакет
COPY pyproject.toml ./
COPY src ./src

RUN "${VENV_PATH}/bin/pip" install .


FROM python:3.10-slim AS test

ENV VENV_PATH=/opt/venv \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update \
 && apt-get install -y --no-install-recommends gcc libpq5 \
 && rm -rf /var/lib/apt/lists/*

 RUN python -m pip install --no-cache-dir -e . \
 && python -m pip install --no-cache-dir pytest

COPY --from=builder "${VENV_PATH}" "${VENV_PATH}"

COPY pyproject.toml ./
COPY src ./src
COPY tests ./tests

# подтягиваем тестовые зависимости (pytest и т.п.)
RUN "${VENV_PATH}/bin/pip" install -e ".[test]"

CMD ["python", "-m", "pytest", "-v", "tests"]


FROM python:3.10-slim AS runtime

ENV VENV_PATH=/opt/venv \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:${PATH}"

WORKDIR /app

RUN apt-get update \
 && apt-get install -y --no-install-recommends libpq5 \
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder "${VENV_PATH}" "${VENV_PATH}"
COPY --from=builder /app/src /app/src

RUN useradd -u 1000 -m appuser \
 && chown -R appuser:appuser /app

USER appuser

EXPOSE 8060
CMD ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8060"]
