"""Interface web (Flask) para ingerir PDFs e fazer perguntas."""
import os

from flask import Flask, flash, redirect, render_template, request, url_for
from werkzeug.utils import secure_filename

from .ingest import ingest_pdf
from .query import answer_question
import markdown


app = Flask(__name__)
# Chave usada pelo Flask para assinar a "sessão"/mensagens flash.
app.secret_key = os.getenv("FLASK_SECRET_KEY", "dev-secret-nao-usar-em-producao")

# Pasta onde os PDFs enviados pela interface ficam salvos.
UPLOAD_DIR = os.path.join(os.getcwd(), "data", "pdfs")
os.makedirs(UPLOAD_DIR, exist_ok=True)

ALLOWED_EXTENSIONS = {"pdf"}


def _allowed(filename: str) -> bool:
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS

def _render_markdown(texto: str) -> str:
    """Converte o texto em Markdown (que o modelo envia) para HTML.

    As extensões permitem blocos de código (```) e tabelas.
    """
    return markdown.markdown(
        texto,
        extensions=["fenced_code", "tables"],
    )

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
        # Converte o Markdown da resposta para HTML para exibir formatado.
        resposta_html = _render_markdown(resposta)
        return render_template(
            "index.html",
            pergunta=pergunta,
            resposta_html=resposta_html,
        )
    except Exception as e:
        flash(f"Erro ao responder: {e}", "erro")
        return redirect(url_for("index"))



if __name__ == "__main__":
    # host 0.0.0.0 permite conexões de fora do contêiner.
    app.run(host="0.0.0.0", port=5000, debug=False)
