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

## Modelo de embeddings e reingestão

O projeto usa `intfloat/multilingual-e5-large` (configurável em `EMBEDDING_MODEL`
no `.env`). Esse modelo exige prefixos: `query: ` nas perguntas e `passage: `
nos trechos dos documentos. O código já aplica ambos automaticamente.

Sempre que o modelo de embeddings mudar, os vetores antigos ficam incompatíveis.
Recrie a coleção e reingira **todos** os PDFs de `data/pdfs`:

```bash
python -m app.reingest
# ou, dentro do Docker:
docker compose run --rm app python -m app.reingest
```
