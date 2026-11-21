# RAG Local — Estudos com PDF, Flask, LangChain e Qdrant

Sistema **RAG (Retrieval-Augmented Generation)** para uso local: você envia PDFs, o sistema transforma o conteúdo em vetores semânticos com o modelo `intfloat/multilingual-e5-large`, armazena no **Qdrant** e responde perguntas usando **apenas o conteúdo recuperado** — sem inventar respostas fora do material.

A interface web é feita em **Flask**. O "motor de resposta" é o **DeepSeek Flash** via **OpenCode Zen** (API compatível com OpenAI), consumido online por uma chave de API.

---

## ✨ Funcionalidades

- **Ingestão de PDFs**: envie um ou mais PDFs pela interface.
- **Busca semântica**: encontra trechos pelo *significado*, não só por palavras exatas.
- **Respostas ancoradas no material**: o modelo usa os trechos recuperados como contexto e avisa quando a resposta não está no material.
- **Prefixos E5 corretos**: ingestão usa `passage: ` e consulta usa `query: `, conforme exige o modelo.
- **Recuperação configurável**: `TOP_K=8` por padrão.
- **Modelo de embeddings 100% local**: não consome créditos da API de chat.

---

## 🧠 Como funciona

```
PDF → Flask → LangChain divide em chunks → prefixo "passage: "
    → embeddings locais → Qdrant

Pergunta → prefixo "query: " → Qdrant busca os TOP_K trechos mais parecidos
         → LangChain monta o contexto → DeepSeek Flash responde
```

> 💡 **Por que os prefixos são obrigatórios?**
> O `intfloat/multilingual-e5-large` é um modelo de embeddings *assimétrico e instruído*. Ele foi treinado para diferenciar perguntas (`query: `) de documentos (`passage: `). Sem esses prefixos, a qualidade da busca cai bastante.

---

## 🧱 Stack e responsabilidade de cada peça

| Componente | O que faz neste projeto |
|---|---|
| **Flask** | Interface web e rotas HTTP: recebe PDFs, envia perguntas e exibe respostas. |
| **LangChain** | Lê PDFs, divide em chunks, monta o contexto e o prompt enviado ao modelo. |
| **Qdrant** | Banco de dados vetorial: guarda os embeddings e faz busca por similaridade. |
| **Sentence-Transformers / Hugging Face** | Carrega o modelo de embeddings e transforma texto em vetores. |
| **PyTorch** | Motor matemático usado pelo modelo de embeddings em CPU. |
| **DeepSeek Flash (OpenCode Zen)** | Modelo de linguagem que escreve a resposta final com base no contexto. |
| **pypdf** | Extração de texto dos PDFs via `PyPDFLoader`. |
| **python-dotenv** | Carrega as variáveis do arquivo `.env`. |
| **uv** | Gerencia as dependências Python (dentro e fora do Docker). |
| **Docker / Docker Compose** | Sobe a aplicação e o Qdrant juntos, sem instalação manual. |

---

## ✅ Requisitos

### Opção A — Docker (recomendado)

- **Docker** e **Docker Compose** instalados.
- Conexão com a internet para baixar as imagens, usar a API do chat e, no primeiro uso, baixar o modelo de embeddings.

### Opção B — Execução local (sem Docker)

- **Python 3.12+** e **uv**.
- **Qdrant** rodando localmente (via Docker ou binário).
- Conexão com a internet pelos mesmos motivos acima.
- **4 GB de RAM no mínimo** — **8 GB recomendado** (o modelo de embeddings + PyTorch consomem bastante memória).

---

## 📁 Estrutura do projeto

```
.
├── app/
│   ├── main.py            # aplicação Flask e rotas
│   ├── config.py          # leitura das variáveis de ambiente
│   ├── ingest.py          # extração, chunking e gravação no Qdrant
│   ├── query.py           # recuperação e resposta com o modelo de chat
│   ├── vector_store.py    # conexão com o Qdrant e modelo de embeddings
│   ├── reingest.py        # recria a coleção e reingere todos os PDFs
│   └── templates/         # template HTML da interface
├── data/pdfs/             # PDFs enviados pela interface
├── pyproject.toml         # dependências Python
├── .env.example           # modelo de variáveis de ambiente
├── .env                   # variáveis reais (NÃO versionar)
├── compose.yaml           # sobe app + Qdrant
└── Dockerfile             # imagem da aplicação
```

---

## ⚙️ Variáveis de ambiente

Crie um arquivo `.env` na raiz do projeto a partir de `.env.example`:

```env
# Modelo de chat (OpenCode Zen)
OPENCODE_BASE_URL=https://opencode.ai/zen/v1
OPENCODE_MODEL=deepseek-v4.1-flash
OPENCODE_API_KEY=sua-chave-aqui

# Modelo de embeddings (local)
EMBEDDING_MODEL=intfloat/multilingual-e5-large

# Qdrant
QDRANT_URL=http://localhost:6333
QDRANT_COLLECTION=estudos

# Busca
TOP_K=8
```

Variáveis opcionais: `QDRANT_API_KEY`, `CHUNK_SIZE` (padrão `1000`), `CHUNK_OVERLAP` (padrão `200`) e `FLASK_SECRET_KEY`.

> ⚠️ **Atenção**
> - Não deixe `OPENCODE_API_KEY` exposta em repositório público.
> - No Docker Compose, `QDRANT_URL` é sobrescrito para `http://qdrant:6333`; fora do Docker, use `http://localhost:6333`.

---

## 🚀 Instalação e execução

### Opção A — Com Docker Compose (recomendado)

1. **Clone o repositório e entre na pasta**

   ```bash
   git clone <url-do-repositorio>
   cd rag-python-qdrant
   ```

2. **Crie o `.env` e preencha a chave da OpenCode Zen**

   ```bash
   cp .env.example .env
   nano .env
   ```

3. **Suba os serviços**

   ```bash
   docker compose up --build
   ```

   Na primeira execução, a imagem é construída, o modelo de embeddings é baixado (pode demorar alguns minutos) e o Qdrant é iniciado.

4. **Acesse** [http://localhost:5000](http://localhost:5000).

5. **Para parar**

   ```bash
   docker compose down
   ```

   Para rodar em segundo plano, use `docker compose up --build -d`.

### Opção B — Sem Docker (ou apenas o Qdrant separado)

1. **Suba o Qdrant** (se ainda não estiver rodando):

   ```bash
   docker compose up -d qdrant
   ```

2. **Instale as dependências** com o uv:

   ```bash
   uv sync
   ```

3. **Configure o `.env`**:

   ```bash
   cp .env.example .env
   nano .env
   ```

   Mantenha `QDRANT_URL=http://localhost:6333`.

4. **Execute a aplicação**:

   ```bash
   uv run python -m app.main
   ```

5. **Acesse** [http://localhost:5000](http://localhost:5000).

---

## 🖥️ Utilização da interface Flask

### 1. Upload/ingestão de PDF

1. Selecione um ou mais arquivos `.pdf`.
2. Envie.

O PDF é salvo em `data/pdfs/` e seus trechos são gravados na coleção configurada.

### 2. Pergunta ao sistema

1. Digite a pergunta e clique em **Perguntar**.
2. Marque **referências** se quiser ver arquivo e página de cada trecho usado.

O sistema recupera os `TOP_K` trechos mais relevantes, monta o contexto e exibe a resposta em Markdown.

---

## 🧪 Teste de validação

Depois de ingerir o material, faça este teste:

**Pergunta:**

> Um investidor aplicou R$ 1.000,00 a juros compostos de 10% ao ano. Qual será o montante após 2 anos?

**Resultado esperado:**

- O contexto deve incluir a fórmula `VF = VP × (1+i)^n`.
- A resposta deve ser **R$ 1.210,00**.

Se a resposta reclamar que a fórmula não está no contexto, verifique:

1. Se o modelo E5 está ativo no `.env`.
2. Se os prefixos `passage: ` e `query: ` estão sendo aplicados.
3. Se `TOP_K` está em **8**.

---

## 🛠️ Solução de problemas comuns

| Sintoma | Causa provável | Correção |
|---|---|---|
| Erro de chave da OpenCode | `OPENCODE_API_KEY` ausente no `.env` | Confira o `.env` e reinicie a aplicação |
| Resposta "não encontrei no contexto" | `TOP_K` baixo, prefixos ausentes ou PDF não ingerido | Ajuste `TOP_K`, confira os prefixos, reingira os PDFs |
| Primeira pergunta muito lenta | Modelo de embeddings carregando/cache ainda não quente | Aguarde; as consultas seguintes ficam rápidas |
| Erro de memória (Killed) | RAM insuficiente | Use máquina/container com 8 GB de RAM |
| PDF com texto quebrado/símbolos estranhos | Extração padrão não entende a fonte/equação | Aceite a limitação do PDF ou converta o arquivo para texto |

---

## 🔒 Segurança

- **Nunca** versione o `.env`.
- Em produção/VPS, exponha o Qdrant **apenas internamente** (não publique a porta `6333`).
- Adicione autenticação na interface antes de expor o Flask à internet.
- Use HTTPS se for acessar fora da sua rede.

---

## ⌨️ Comandos de linha de comando

```bash
# Ingerir um PDF
uv run python -m app.ingest caminho/arquivo.pdf

# Fazer uma pergunta
uv run python -m app.query "sua pergunta"

# Recriar a coleção e reingerir todos os PDFs de data/pdfs
uv run python -m app.reingest
```

No Docker, troque `uv run python` por `docker compose run --rm app python`.

---

## 📚 Referências dos modelos

- Embeddings: [`intfloat/multilingual-e5-large`](https://huggingface.co/intfloat/multilingual-e5-large)
- Banco vetorial: [Qdrant](https://qdrant.tech/)
- Modelo de chat: DeepSeek Flash via [OpenCode Zen](https://opencode.ai/)
- Orquestração: [LangChain](https://python.langchain.com/)

---

## 🔐 Aviso de segurança e escopo

Este repositório é um **projeto de estudos e testes locais**, não um sistema pronto para produção. O foco atual é demonstrar o fluxo de RAG (ingestão, busca vetorial e geração de respostas), e não oferecer isolamento, autenticação ou proteção contra uso malicioso.

**Não exponha a aplicação (porta 5000) nem o Qdrant (portas 6333/6334) diretamente à internet.** Use apenas em máquina local ou rede confiável.

A segurança deve ser ampliada em versões futuras, incluindo pelo menos:

- **Autenticação e autorização** na interface Flask, com rate limit e cota de uso da API.
- **Sanitização da saída Markdown** antes de renderizar HTML, além de CSP e headers de segurança, para prevenir XSS.
- **Limites de upload** (tamanho, páginas e tipo real do arquivo) e controle de disco.
- **Qdrant protegido**: sem publicação de portas, com API key e/ou TLS quando necessário.
- **Bind em loopback por padrão** para Flask e Qdrant, liberando acesso externo apenas de forma explícita.
- **Proteção CSRF** nos formulários e mensagens de erro genéricas, sem detalhes internos.
- **Gestão de segredos**: `.env` com permissão `600`, `FLASK_SECRET_KEY` obrigatória e chave da API nunca versionada.
- **Builds reprodutíveis**: `uv.lock`, `uv sync --frozen` e imagens Docker fixadas por digest.
- **Hardening dos contêineres**: usuário non-root, `no-new-privileges`, `cap_drop` e limites de CPU/memória.
- **Definição de confidencialidade**: os embeddings são locais, mas os trechos recuperados são enviados à API de chat. Evite ingerir documentos sensíveis ou use um modelo local.

Contribuições que melhorem esses pontos são bem-vindas.
