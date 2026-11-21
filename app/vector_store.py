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
    # (Não é uma busca de verdade, mas usamos o prefixo "query: " por coerência.)
    return len(get_embeddings().embed_query("query: teste"))


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


def recreate_collection():
    """Apaga a coleção e a recria vazia.

    Use SEMPRE que o modelo de embeddings mudar: vetores gerados por modelos
    diferentes têm tamanhos/semânticas diferentes e são incompatíveis entre si.
    Depois de recriar, TODOS os PDFs precisam ser ingeridos novamente.
    """
    global _vector_store
    client = get_client()
    try:
        client.delete_collection(collection_name=config.QDRANT_COLLECTION)
        print(f"[qdrant] Coleção '{config.QDRANT_COLLECTION}' apagada.")
    except Exception as e:
        # Se a coleção ainda não existir, seguimos em frente e criamos do zero.
        print(f"[qdrant] Nada para apagar em '{config.QDRANT_COLLECTION}': {e}")

    # Descarta o vector store em cache, pois ele aponta para a coleção antiga.
    _vector_store = None
    ensure_collection()


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
