"""Recria a coleção do Qdrant e reingere TODOS os PDFs de uma pasta.

Necessário sempre que o modelo de embeddings muda: os vetores antigos são
incompatíveis com os novos e a busca passaria a devolver resultados ruins.

Uso:
    python -m app.reingest            # usa data/pdfs
    python -m app.reingest outra/pasta
"""
import sys
from pathlib import Path

from .ingest import ingest_pdf
from .vector_store import recreate_collection

# Mesma pasta usada pela interface web para guardar os PDFs enviados.
PDF_DIR_PADRAO = Path("data/pdfs")


def reingest_all(pdf_dir: str = str(PDF_DIR_PADRAO)) -> tuple[int, int]:
    """Apaga a coleção, recria vazia e ingere cada PDF da pasta.

    Retorna (quantidade de PDFs ingeridos, total de chunks gravados).
    """
    pasta = Path(pdf_dir)
    pdfs = sorted(pasta.glob("*.pdf"))

    if not pdfs:
        print(f"[reingest] Nenhum PDF encontrado em '{pasta}'.")
        print("[reingest] A coleção NÃO foi alterada.")
        return 0, 0

    print("[reingest] ATENÇÃO: a coleção será apagada e recriada.")
    print(f"[reingest] Reingerindo {len(pdfs)} PDF(s) de '{pasta}'...")
    recreate_collection()

    total_chunks = 0
    for pdf in pdfs:
        total_chunks += ingest_pdf(str(pdf))

    print(f"[reingest] Concluído: {len(pdfs)} PDF(s), "
          f"{total_chunks} chunk(s) gravados.")
    return len(pdfs), total_chunks


if __name__ == "__main__":
    diretorio = sys.argv[1] if len(sys.argv) > 1 else str(PDF_DIR_PADRAO)
    reingest_all(diretorio)
