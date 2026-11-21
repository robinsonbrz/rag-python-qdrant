"""Ingestão de PDFs: extrai texto, divide em pedaços e grava no Qdrant.

Fluxo detalhado:
1. PDF -> Documentos (um por página) usando PyPDFLoader.
2. Documentos -> "chunks" (pedaços menores) para facilitar a busca.
3. Chunks -> vetores (embeddings) e gravação na coleção do Qdrant.

O modelo E5 exige o prefixo "passage: " no texto dos documentos ANTES de
gerar o embedding. Por isso ele é aplicado em cada chunk antes do add_documents.

Uso pela linha de comando:
    python -m app.ingest caminho/para/arquivo.pdf

ATENÇÃO: ao trocar o modelo de embeddings, recrie a coleção e reingira
TODOS os PDFs:  python -m app.reingest
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

    # --- 3) Aplicar o prefixo exigido pelo modelo E5 ---
    # O prefixo precisa estar no texto ANTES de o embedding ser calculado:
    # o add_documents vetoriza exatamente o page_content de cada chunk.
    for doc in chunks:
        doc.page_content = f"passage: {doc.page_content}"
    print("[ingest] Prefixo 'passage: ' aplicado aos chunks.")

    # --- 4) Gerar embeddings e gravar ---
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
