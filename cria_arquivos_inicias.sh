#!/usr/bin/env bash
#
# Gera o projeto "Assistente de Estudos com RAG" (LangChain + Qdrant + Flask).
#
# Uso:
#   chmod +x gerar_projeto.sh
#   ./gerar_projeto.sh [nome_da_pasta]
#
# O nome padrão da pasta é "rag-estudos".
set -euo pipefail

ROOT="${1:-rag-estudos}"

echo "==> Criando a estrutura do projeto em: $ROOT"
mkdir -p "$ROOT/app/templates"
mkdir -p "$ROOT/data/pdfs"

# Função auxiliar: escreve um arquivo a partir de um heredoc.
# Uso: gravar "caminho/relativo" <<'EOF' ... EOF
gravar() {
  local destino="$ROOT/$1"
  mkdir -p "$(dirname "$destino")"
  cat > "$destino"
}

# ---------------------------------------------------------------------------
# compose.yaml
# ---------------------------------------------------------------------------
gravar "compose.yaml" <<'EOF'
# ============================================================
#  Docker Compose — define os dois contêineres do sistema:
#   1) qdrant : banco de dados vetorial
#   2) app    : aplicação Python (interface web + RAG)
# ============================================================

services:
  # ----------------------------------------------------------------
  # QDRANT — banco vetorial que guarda os "pedaços" dos PDFs já
  # transformados em vetores (embeddings). Os dados ficam em um
  # volume para sobreviverem a reinícios do contêiner.
  # ----------------------------------------------------------------
  qdrant:
    image: qdrant/qdrant:latest
    container_name: qdrant
    ports:
      - "6333:6333"   # API REST — usada pela aplicação Python
      - "6334:6334"   # gRPC — não usamos, mas é exposto por padrão
    volumes:
      - qdrant_data:/qdrant/storage
    # Sem senha: adequado apenas para estudos em máquina local.
    # Em produção, defina a variável QDRANT__SERVICE__API_KEY.

  # ----------------------------------------------------------------
  # APP — aplicação Python (Flask). Sobe a interface web na porta 5000.
  # ----------------------------------------------------------------
  app:
    build: .
    container_name: app-rag
    depends_on:
      - qdrant
    ports:
      - "5000:5000"
    env_file:
      - .env           # carrega a chave da OpenCode Zen e demais configs
    environment:
      # Dentro da rede do Compose, o app alcança o Qdrant pelo NOME do
      # serviço ("qdrant"), e não por "localhost".
      QDRANT_URL: http://qdrant:6333
    volumes:
      - ./data:/app/data                      # PDFs enviados ficam no host
      - hf_cache:/app/.cache/huggingface      # cache do modelo de embeddings

volumes:
  qdrant_data:
  hf_cache:
EOF

# ---------------------------------------------------------------------------
# Dockerfile
# ---------------------------------------------------------------------------
gravar "Dockerfile" <<'EOF'
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
EOF

# ---------------------------------------------------------------------------
# .dockerignore
# ---------------------------------------------------------------------------
gravar ".dockerignore" <<'EOF'
.git
.env
data/
.venv
__pycache__
*.pyc
.cache
EOF

# ---------------------------------------------------------------------------
# .gitignore
# ---------------------------------------------------------------------------
gravar ".gitignore" <<'EOF'
# Segredos — NUNCA versione este arquivo
.env

# PDFs enviados e dados locais
data/

# Ambiente virtual e cache do Python
.venv/
__pycache__/
*.pyc

# Cache local do modelo de embeddings (uso fora do Docker)
.cache/

# Padrões de sistema
.DS_Store
EOF

# ---------------------------------------------------------------------------
# pyproject.toml (dependências gerenciadas pelo uv)
# ---------------------------------------------------------------------------
gravar "pyproject.toml" <<'EOF'
[project]
name = "rag-estudos"
version = "0.1.0"
description = "Assistente de estudos com RAG usando LangChain, Qdrant e Flask"
requires-python = ">=3.12"
dependencies = [
    "langchain>=0.3.0,<1.0",
    "langchain-community>=0.3.0,<1.0",
    "langchain-openai>=0.3.0,<1.0",
    "langchain-huggingface>=0.2.0,<1.0",
    "langchain-qdrant>=0.2.0,<1.0",
    "langchain-text-splitters>=0.3.0,<1.0",
    "qdrant-client>=1.12.0",
    "pypdf>=5.1.0",
    "sentence-transformers>=3.3.0",
    "python-dotenv>=1.0.1",
    "flask>=3.1.0,<4.0",
]

[tool.uv]
# Não empacotamos/instalamos o projeto como biblioteca.
# Usamos o uv apenas para gerenciar as dependências.
package = false
EOF

# ---------------------------------------------------------------------------
# .env.example
# ---------------------------------------------------------------------------
gravar ".env.example" <<'EOF'
# ============================================================
#  Copie este arquivo para ".env" e preencha a sua chave:
#      cp .env.example .env
#  O arquivo ".env" NÃO deve ser versionado (já está no .gitignore).
# ============================================================

# ------------------------------------------------------------
# OpenCode Zen (modelo de chat) — VALORES QUE VOCÊ DEVE CONFIRMAR
# na documentação da sua conta OpenCode Zen.
# ------------------------------------------------------------
# Base URL da API (exemplo declarado na documentação da OpenCode Zen).
# ATENÇÃO: se a sua conta exigir, use "https://opencode.ai/v1".
OPENCODE_BASE_URL=https://opencode.ai

# Identificador do modelo ("DeepSeek Flash").
OPENCODE_MODEL=deepseek-v4.1-flash

# SUA CHAVE DE ACESSO — único valor obrigatório e secreto.
# Não compartilhe nem coloque no código.
OPENCODE_API_KEY=COLOQUE_SUA_CHAVE_AQUI

# ------------------------------------------------------------
# Embeddings (modelo LOCAL que transforma texto em vetores).
# Não exige chave nem conta. Pode deixar como está.
# ------------------------------------------------------------
EMBEDDING_MODEL=sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2

# ------------------------------------------------------------
# Qdrant (banco vetorial) — valores comuns para uso local.
# ------------------------------------------------------------
# Nome da "coleção" (equivalente a uma tabela) onde os vetores ficam.
QDRANT_COLLECTION=estudos

# ------------------------------------------------------------
# Opcional: ajustes de divisão do texto e de busca.
# Pode deixar comentado (os padrões serão usados).
# ------------------------------------------------------------
# CHUNK_SIZE=1000
# CHUNK_OVERLAP=200
# TOP_K=4
# FLASK_SECRET_KEY=troque-em-producao
EOF

# ---------------------------------------------------------------------------
# app/__init__.py
# ---------------------------------------------------------------------------
gravar "app/__init__.py" <<'EOF'
"""Pacote da aplicação: assistente de estudos com RAG."""
EOF

# ---------------------------------------------------------------------------
# app/config.py
# ---------------------------------------------------------------------------
gravar "app/config.py" <<'EOF'
"""Configurações da aplicação, carregadas de variáveis de ambiente.

Este módulo centraliza tudo que é "configurável" (chaves, URLs e nomes)
para que nenhum segredo fique escrito no código-fonte.
"""
import os

from dotenv import load_dotenv

# Carrega o arquivo ".env" se ele existir (útil ao rodar fora do Docker).
# No Docker, as variáveis já chegam pelo "env_file" do Compose.
load_dotenv()

# ---------------------------------------------------------------------------
# OpenCode Zen (modelo de chat)
# ATENÇÃO: confirme estes valores na documentação da OpenCode Zen.
# ---------------------------------------------------------------------------
OPENCODE_BASE_URL = os.getenv("OPENCODE_BASE_URL", "https://opencode.ai")
OPENCODE_MODEL = os.getenv("OPENCODE_MODEL", "deepseek-v4.1-flash")
OPENCODE_API_KEY = os.getenv("OPENCODE_API_KEY", "")

# ---------------------------------------------------------------------------
# Embeddings (modelo local de vetores)
# ---------------------------------------------------------------------------
EMBEDDING_MODEL = os.getenv(
    "EMBEDDING_MODEL",
    "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2",
)

# ---------------------------------------------------------------------------
# Qdrant (banco de dados vetorial)
# ---------------------------------------------------------------------------
# Dentro do Docker, o Compose sobrescreve este valor para http://qdrant:6333.
QDRANT_URL = os.getenv("QDRANT_URL", "http://localhost:6333")
# Vazio = sem autenticação (adequado para uso local de estudos).
QDRANT_API_KEY = os.getenv("QDRANT_API_KEY", "")
QDRANT_COLLECTION = os.getenv("QDRANT_COLLECTION", "estudos")

# ---------------------------------------------------------------------------
# Divisão dos textos (chunking) e busca
# ---------------------------------------------------------------------------
CHUNK_SIZE = int(os.getenv("CHUNK_SIZE", "1000"))
CHUNK_OVERLAP = int(os.getenv("CHUNK_OVERLAP", "200"))
TOP_K = int(os.getenv("TOP_K", "4"))
EOF

# ---------------------------------------------------------------------------
# app/vector_store.py
# ---------------------------------------------------------------------------
gravar "app/vector_store.py" <<'EOF'
"""Conexão com o Qdrant (banco vetorial) e criação do modelo de embeddings.

Fluxo em alto nível:
1. Carregamos um modelo LOCAL de embeddings, que transforma texto em vetores
   (listas de números que representam o significado do texto).
2. Conectamos ao Qdrant usando o cliente oficial.
3. Garantimos que a "coleção" (equivalente a uma tabela) exista, criando-a
   com o tamanho de vetor correto caso ainda não exista.
4. Devolvemos um objeto "vector store" que o LangChain usa tanto para GRAVAR
   os trechos dos PDFs quanto para BUSCAR por semelhança.
"""
import time

from langchain_huggingface import HuggingFaceEmbeddings
from langchain_qdrant import QdrantVectorStore
from qdrant_client import QdrantClient
from qdrant_client.http.models import Distance, VectorParams

from . import config

# Cache em nível de módulo: o modelo de embeddings é pesado, então carregamos
# apenas UMA vez por processo, e não a cada pergunta.
_embeddings = None
_client = None
_vector_store = None


def get_embeddings():
    """Devolve o modelo de embeddings local (carregado uma única vez)."""
    global _embeddings
    if _embeddings is None:
        print(f"[embeddings] Carregando modelo {config.EMBEDDING_MODEL} "
              "(a primeira vez pode demorar)...")
        _embeddings = HuggingFaceEmbeddings(
            model_name=config.EMBEDDING_MODEL,
            # 'cpu' porque o contêiner de estudo não usa GPU.
            model_kwargs={"device": "cpu"},
            # Normalizar ajuda na similaridade de cosseno.
            encode_kwargs={"normalize_embeddings": True},
        )
    return _embeddings


def get_client():
    """Devolve o cliente do Qdrant (criado uma única vez)."""
    global _client
    if _client is None:
        _client = QdrantClient(
            url=config.QDRANT_URL,
            # Chave vazia significa "sem autenticação" (uso local).
            api_key=config.QDRANT_API_KEY or None,
        )
    return _client


def _vector_size() -> int:
    """Descobre o tamanho dos vetores gerados pelo modelo de embeddings."""
    # Embeddings do mesmo modelo têm sempre o mesmo tamanho; medimos uma vez.
    return len(get_embeddings().embed_query("teste"))


def _existing_collections(client) -> set:
    """Lista as coleções existentes, com retries no início do sistema."""
    # Logo após o "docker compose up", o Qdrant pode levar alguns segundos
    # para aceitar conexões. Por isso tentamos algumas vezes.
    ultimo_erro = None
    for tentativa in range(1, 6):
        try:
            return {c.name for c in client.get_collections().collections}
        except Exception as e:
            ultimo_erro = e
            print(f"[qdrant] Conexão ainda não disponível "
                  f"(tentativa {tentativa}/5). Aguardando...")
            time.sleep(3)
    raise ultimo_erro


def ensure_collection():
    """Cria a coleção no Qdrant caso ela ainda não exista."""
    client = get_client()
    if config.QDRANT_COLLECTION not in _existing_collections(client):
        size = _vector_size()
        client.create_collection(
            collection_name=config.QDRANT_COLLECTION,
            vectors_config=VectorParams(size=size, distance=Distance.COSINE),
        )
        print(f"[qdrant] Coleção '{config.QDRANT_COLLECTION}' criada "
              f"(vetores de tamanho {size}).")


def get_vector_store():
    """Devolve o objeto que o LangChain usa para gravar/buscar vetores."""
    global _vector_store
    if _vector_store is None:
        ensure_collection()
        _vector_store = QdrantVectorStore(
            client=get_client(),
            collection_name=config.QDRANT_COLLECTION,
            embedding=get_embeddings(),
        )
    return _vector_store
EOF

# ---------------------------------------------------------------------------
# app/ingest.py
# ---------------------------------------------------------------------------
gravar "app/ingest.py" <<'EOF'
"""Ingestão de PDFs: extrai texto, divide em pedaços e grava no Qdrant.

Fluxo detalhado:
1. PDF -> Documentos (um por página) usando PyPDFLoader.
2. Documentos -> "chunks" (pedaços menores) para facilitar a busca.
3. Chunks -> vetores (embeddings) e gravação na coleção do Qdrant.

Uso pela linha de comando:
    python -m app.ingest caminho/para/arquivo.pdf
"""
import sys

from langchain_community.document_loaders import PyPDFLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter

from . import config
from .vector_store import get_vector_store


def ingest_pdf(pdf_path: str) -> int:
    """Ingere um único PDF e retorna quantos chunks foram gravados."""
    print(f"[ingest] Lendo PDF: {pdf_path}")

    # --- 1) Extrair texto ---
    # PyPDFLoader lê o PDF e gera um Document por página. Cada Document carrega
    # metadados como "source" (caminho do arquivo) e "page" (número da página).
    loader = PyPDFLoader(pdf_path)
    docs = loader.load()
    print(f"[ingest] {len(docs)} páginas extraídas.")

    if not docs:
        print("[ingest] Nenhum texto encontrado (o PDF pode ser digitalizado/imagem).")
        return 0

    # --- 2) Dividir em chunks ---
    # Textos muito longos atrapalham a busca; pedaços menores criam
    # correspondências mais precisas. O "overlap" mantém contexto entre pedaços.
    splitter = RecursiveCharacterTextSplitter(
        chunk_size=config.CHUNK_SIZE,
        chunk_overlap=config.CHUNK_OVERLAP,
        separators=["\n\n", "\n", ".", " ", ""],
    )
    chunks = splitter.split_documents(docs)
    print(f"[ingest] {len(chunks)} chunks gerados.")

    # --- 3) Gerar embeddings e gravar ---
    # O add_documents faz: transformar cada chunk em vetor (modelo local)
    # e gravar vetores + texto + metadados no Qdrant.
    get_vector_store().add_documents(chunks)
    print(f"[ingest] {len(chunks)} chunks gravados na coleção "
          f"'{config.QDRANT_COLLECTION}'.")
    return len(chunks)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Uso: python -m app.ingest <caminho/do/arquivo.pdf>")
        sys.exit(1)
    n = ingest_pdf(sys.argv[1])
    print(f"Concluído: {n} chunks ingeridos.")
EOF

# ---------------------------------------------------------------------------
# app/query.py
# ---------------------------------------------------------------------------
gravar "app/query.py" <<'EOF'
"""Consulta: recebe uma pergunta, recupera trechos e responde com o modelo.

Fluxo RAG (Retrieval-Augmented Generation):
1. A pergunta é "vetorizada" e comparada com os chunks gravados no Qdrant.
2. Os K trechos mais parecidos viram o CONTEXTO.
3. Montamos um PROMPT com esse contexto + a pergunta.
4. O modelo de chat (OpenCode Zen) responde com base no contexto, em vez de
   responder apenas com o que já sabe.
"""
import os
import sys

from langchain_core.messages import HumanMessage, SystemMessage
from langchain_openai import ChatOpenAI

from . import config
from .vector_store import get_vector_store

SYSTEM_PROMPT = (
    "Você é um assistente de estudos. Responda com base no CONTEXTO fornecido.\n"
    "Regras:\n"
    "1. Priorize as informações do CONTEXTO.\n"
    "2. Explique de forma clara, objetiva e útil.\n"
    "3. Se o CONTEXTO não permitir responder, diga claramente que o material "
    "não contém a informação — NÃO invente.\n"
    "4. Responda em português.\n"
    "5. Cite nome de arquivo e página apenas se o usuário pedir referências "
    "e apenas quando essas informações existirem no CONTEXTO."
)

# Cache do modelo para não recriá-lo a cada pergunta.
_llm = None


def get_llm():
    """Cria (uma única vez) o modelo de chat da OpenCode Zen."""
    global _llm
    if _llm is None:
        # temperature baixo => respostas mais estáveis e fiéis ao contexto.
        _llm = ChatOpenAI(
            api_key=config.OPENCODE_API_KEY,
            base_url=config.OPENCODE_BASE_URL,
            model=config.OPENCODE_MODEL,
            temperature=0.2,
        )
    return _llm


def _format_context(docs, include_sources: bool) -> str:
    """Junta os trechos recuperados em um único texto, numerados."""
    partes = []
    for i, doc in enumerate(docs, start=1):
        texto = doc.page_content.strip()
        if include_sources:
            fonte = os.path.basename(doc.metadata.get("source", "desconhecido"))
            pagina = doc.metadata.get("page")
            pagina_label = f"{pagina + 1}" if isinstance(pagina, int) else (pagina or "n/d")
            cabecalho = f"[Trecho {i} — arquivo: {fonte}, página: {pagina_label}]"
        else:
            cabecalho = f"[Trecho {i}]"
        partes.append(f"{cabecalho}\n{texto}")
    return "\n\n".join(partes)


def answer_question(question: str, include_sources: bool = False) -> str:
    """Responde uma pergunta usando RAG. Retorna o texto da resposta."""
    store = get_vector_store()

    # --- 1) Recuperação (Retrieval) ---
    # similarity_search vetoriza a pergunta e devolve os chunks mais parecidos.
    docs = store.similarity_search(question, k=config.TOP_K)
    if not docs:
        return (
            "Não encontrei nenhum conteúdo relevante no material ingerido. "
            "Envie/ingira um PDF antes de perguntar."
        )

    contexto = _format_context(docs, include_sources)

    # --- 2) Geração (Generation) ---
    # Montamos o prompt com o contexto + a pergunta e pedimos a resposta.
    user_message = (
        f"CONTEXTO (trechos do material de estudo):\n{contexto}\n\n"
        f"PERGUNTA: {question}\n\n"
        "Use o CONTEXTO para responder. Se ele não for suficiente, "
        "diga isso claramente."
    )

    response = get_llm().invoke([
        SystemMessage(content=SYSTEM_PROMPT),
        HumanMessage(content=user_message),
    ])
    return response.content


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python -m app.query 'sua pergunta aqui'")
        sys.exit(1)
    pergunta = " ".join(sys.argv[1:])
    print(answer_question(pergunta, include_sources=True))
EOF

# ---------------------------------------------------------------------------
# app/main.py
# ---------------------------------------------------------------------------
gravar "app/main.py" <<'EOF'
"""Interface web (Flask) para ingerir PDFs e fazer perguntas."""
import os

from flask import Flask, flash, redirect, render_template, request, url_for
from werkzeug.utils import secure_filename

from .ingest import ingest_pdf
from .query import answer_question

app = Flask(__name__)
# Chave usada pelo Flask para assinar a "sessão"/mensagens flash.
app.secret_key = os.getenv("FLASK_SECRET_KEY", "dev-secret-nao-usar-em-producao")

# Pasta onde os PDFs enviados pela interface ficam salvos.
UPLOAD_DIR = os.path.join(os.getcwd(), "data", "pdfs")
os.makedirs(UPLOAD_DIR, exist_ok=True)

ALLOWED_EXTENSIONS = {"pdf"}


def _allowed(filename: str) -> bool:
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS


@app.get("/")
def index():
    return render_template("index.html")


@app.post("/ingest")
def ingest():
    """Recebe um PDF via formulário, salva e processa no Qdrant."""
    arquivo = request.files.get("arquivo")
    if not arquivo or arquivo.filename == "":
        flash("Nenhum arquivo selecionado.", "erro")
        return redirect(url_for("index"))
    if not _allowed(arquivo.filename):
        flash("Envie um arquivo PDF.", "erro")
        return redirect(url_for("index"))

    nome = secure_filename(arquivo.filename)
    caminho = os.path.join(UPLOAD_DIR, nome)
    arquivo.save(caminho)

    try:
        n = ingest_pdf(caminho)
        flash(f"'{nome}' ingerido com sucesso: {n} trechos gravados.", "ok")
    except Exception as e:
        flash(f"Falha ao ingerir '{nome}': {e}", "erro")
    return redirect(url_for("index"))


@app.post("/ask")
def ask():
    """Recebe uma pergunta e devolve a resposta gerada com RAG."""
    pergunta = request.form.get("pergunta", "").strip()
    if not pergunta:
        flash("Digite uma pergunta.", "erro")
        return redirect(url_for("index"))

    incluir_referencias = request.form.get("referencias") == "on"
    try:
        resposta = answer_question(pergunta, include_sources=incluir_referencias)
        return render_template("index.html", pergunta=pergunta, resposta=resposta)
    except Exception as e:
        flash(f"Erro ao responder: {e}", "erro")
        return redirect(url_for("index"))


if __name__ == "__main__":
    # host 0.0.0.0 permite conexões de fora do contêiner.
    app.run(host="0.0.0.0", port=5000, debug=False)
EOF

# ---------------------------------------------------------------------------
# app/templates/index.html
# ---------------------------------------------------------------------------
gravar "app/templates/index.html" <<'EOF'
<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Assistente de Estudos (RAG)</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 780px; margin: 2rem auto; padding: 0 1rem; color: #1c2733; }
    h1 { font-size: 1.6rem; }
    section { background: #f5f7fa; border: 1px solid #dde3ea; border-radius: 10px; padding: 1.2rem; margin: 1.2rem 0; }
    label { display: block; font-weight: 600; margin: .35rem 0; }
    textarea { width: 100%; min-height: 90px; padding: .6rem; border: 1px solid #c3cdd9; border-radius: 6px; font: inherit; }
    input[type=file] { font: inherit; }
    button { background: #2563eb; color: #fff; border: 0; padding: .55rem 1.1rem; border-radius: 6px; cursor: pointer; font: inherit; }
    button:hover { background: #1d4ed8; }
    .flash { padding: .6rem .9rem; border-radius: 6px; margin: .6rem 0; }
    .flash.ok { background: #dcfce7; color: #14532d; }
    .flash.erro { background: #fee2e2; color: #7f1d1d; }
    .resposta { white-space: pre-wrap; background: #fff; border: 1px solid #dde3ea; border-radius: 8px; padding: 1rem; }
  </style>
</head>
<body>
  <h1>📚 Assistente de Estudos (RAG)</h1>
  <p>Envie um PDF e depois faça perguntas sobre o conteúdo dele.</p>

  {% with mensagens = get_flashed_messages(with_categories=true) %}
    {% for categoria, msg in mensagens %}
      <div class="flash {{ categoria }}">{{ msg }}</div>
    {% endfor %}
  {% endwith %}

  <section>
    <h2>1. Ingerir PDF</h2>
    <form method="post" action="/ingest" enctype="multipart/form-data">
      <label for="arquivo">Selecione um PDF com texto:</label>
      <input type="file" id="arquivo" name="arquivo" accept=".pdf" required>
      <br><br>
      <button type="submit">Enviar e processar</button>
    </form>
  </section>

  <section>
    <h2>2. Fazer pergunta</h2>
    <form method="post" action="/ask">
      <label for="pergunta">Pergunta:</label>
      <textarea id="pergunta" name="pergunta" placeholder="Ex.: Explique o conceito de ..." required>{{ pergunta or "" }}</textarea>
      <br>
      <label><input type="checkbox" name="referencias"> Incluir referências (arquivo/página)</label>
      <br><br>
      <button type="submit">Perguntar</button>
    </form>

    {% if resposta %}
      <h3>Resposta</h3>
      <div class="resposta">{{ resposta }}</div>
    {% endif %}
  </section>
</body>
</html>
EOF

# ---------------------------------------------------------------------------
# README.md
# ---------------------------------------------------------------------------
gravar "README.md" <<'EOF'
# 📚 Assistente de Estudos com RAG (LangChain + Qdrant + Flask)

Este projeto é um **assistente de estudos**: você envia PDFs com texto do seu
material e depois faz perguntas sobre o conteúdo. As respostas são geradas **com
base nos trechos do PDF**, e não apenas no "conhecimento de memória" do modelo.

## O que significa RAG?

**RAG = Retrieval-Augmented Generation** ("geração aumentada por recuperação").

Em vez de mandar só a pergunta para o modelo de IA, o sistema faz duas etapas:

1. **Recuperação (Retrieval):** procura no banco vetorial os trechos do PDF mais
   parecidos com a sua pergunta.
2. **Geração (Generation):** envia esses trechos como **contexto** junto com a
   pergunta para o modelo de IA (DeepSeek Flash, via OpenCode Zen).

Isso faz o assistente preferir o que está no seu material e **evitar inventar**
respostas.

## Como funciona, em resumo

### Ingestão de PDF
