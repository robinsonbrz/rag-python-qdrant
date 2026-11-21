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
# O modelo E5 é "instruction-tuned" e exige prefixos no texto:
#   - "query: " para perguntas (ver app/query.py)
#   - "passage: " para trechos de documentos (ver app/ingest.py)
# Sem esses prefixos a qualidade da busca cai bastante.
# ATENÇÃO: ao trocar de modelo é preciso RECRIAR a coleção do Qdrant e
# reingerir TODOS os PDFs (vetores de modelos diferentes são incompatíveis).
EMBEDDING_MODEL = os.getenv(
    "EMBEDDING_MODEL",
    "intfloat/multilingual-e5-large",
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
TOP_K = int(os.getenv("TOP_K", "8"))
