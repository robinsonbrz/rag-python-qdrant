# Imagem base com Python 3.12 e a ferramenta uv já instalada.
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim

WORKDIR /app

# UV_COMPILE_BYTECODE: gera .pyc (início mais rápido).
# UV_LINK_MODE=copy: necessário para camadas Docker consistentes.
# HF_HOME: guarda o modelo de embeddings em pasta cacheada por volume.
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    HF_HOME=/app/.cache/huggingface

# 1) Copia APENAS o pyproject.toml e instala as dependências.
#    Como o código ainda não mudou, o Docker reaproveita esta camada
#    (cache) quando só o nosso código Python for alterado.
COPY pyproject.toml ./
RUN uv sync --no-dev

# 2) Copia o código da aplicação.
COPY app ./app

# Torna o ambiente virtual do uv disponível no PATH.
ENV PATH="/app/.venv/bin:$PATH"

# Porta usada pelo Flask.
EXPOSE 5000

# Comando que inicia a interface web.
CMD ["python", "-m", "app.main"]
