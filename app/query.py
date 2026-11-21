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
        # O prefixo "passage: " serve só para o embedding; removemos da
        # exibição para o contexto do modelo ficar mais limpo.
        texto = doc.page_content.strip().removeprefix("passage: ")
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
    # O modelo E5 exige o prefixo "query: " na pergunta antes de vetorizá-la.
    # similarity_search vetoriza a pergunta e devolve os chunks mais parecidos.
    query_com_prefixo = f"query: {question}"
    docs = store.similarity_search(query_com_prefixo, k=config.TOP_K)
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
