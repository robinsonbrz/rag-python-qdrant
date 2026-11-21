# RAG Local — Estudos com PDF, Flask, LangChain e Qdrant

Sistema **RAG (Retrieval-Augmented Generation)** para uso local: você envia PDFs, o sistema transforma o conteúdo em vetores semânticos com o modelo `intfloat/multilingual-e5-large`, armazena no **Qdrant** e responde perguntas usando **apenas o conteúdo recuperado** — sem inventar respostas fora do material.

A interface web é feita em **Flask**. O "motor de resposta" é o **DeepSeek Flash** via OpenCode (API compatível com OpenAI), consumido online por uma chave de API.

---

## ✨ Funcionalidades

- **Ingestão de PDFs**: envie um ou mais PDFs pela interface.
- **Busca semântica**: encontra trechos pelo *significado*, não só por palavras exatas.
- **Respostas ancoradas no material**: o modelo usa os trechos recuperados como contexto.
- **Trava anti-alucinação**: se o contexto não contém a resposta, o sistema avisa em vez de chutar.
- **Prefixos E5 corretos**: ingestão usa `passage: ` e consulta usa `query: `, conforme exige o modelo.
- **Recuperação com `k=8`**: mais trechos no contexto para melhorar a chance de acertar.
- **Modelo de embeddings 100% local**: não consome créditos da API de chat.

---

## 🧠 Fluxo geral (como tudo se encaixa)

### 1. Ingestão de um PDF

```
PDF enviado pela interface
        │
        ▼
Flask recebe o arquivo
        │
        ▼
LangChain lê e divide o texto em chunks
        │
        ▼
Cada chunk é prefixado com "passage: "
        │
        ▼
Sentence-Transformers + PyTorch geram os embeddings (texto → números)
        │
        ▼
Qdrant armazena os vetores
```

### 2. Consulta (pergunta do usuário)

```
Pergunta digitada na interface
        │
        ▼
Flask recebe a pergunta
        │
        ▼
A pergunta é prefixada com "query: "
        │
        ▼
Qdrant busca os "k" trechos mais parecidos (k=8)
        │
        ▼
LangChain monta o contexto com esses trechos
        │
        ▼
DeepSeek Flash responde usando só o contexto
        │
        ▼
Flask exibe a resposta na tela
```

> 💡 **Por que os prefixos são obrigatórios?**
> O `intfloat/multilingual-e5-large` é um modelo de embeddings *assimétrico e instruído*. Ele foi treinado para diferenciar perguntas (`query: `) de documentos (`passage: `). Sem esses prefixos, a qualidade da busca cai bastante.

---

## 🧱 Stack e responsabilidade de cada peça

| Componente | O que faz neste projeto |
|---|---|
| **Flask** | Interface web e API HTTP. Recebe PDFs, exibe a página, envia perguntas e mostra respostas. |
| **LangChain** | Camada de orquestração. Lê PDFs, divide em pedaços, gerencia o fluxo de recuperação e monta o prompt enviado ao modelo. |
| **Qdrant** | Banco de dados vetorial. Guarda os embeddings e faz busca por similaridade (semelhança semântica). |
| **Sentence-Transformers** | Carrega o modelo de embeddings (`multilingual-e5-large`) e transforma texto em vetores numéricos. |
| **PyTorch** | Motor matemático usado pelo Sentence-Transformers para rodar o modelo de embeddings em CPU/GPU. |
| **DeepSeek Flash (OpenCode)** | Modelo de linguagem que **escreve a resposta final** com base no contexto recuperado. Roda via API online e usa a chave configurada. |
| **python-dotenv** | Carrega as variáveis do arquivo `.env` para dentro da aplicação. |
| **pypdf / pymupdf** | Bibliotecas de extração de texto dos PDFs. |
| **Docker / Docker Compose (opcional)** | Facilita subir a aplicação e o Qdrant juntos, sem instalar tudo manualmente. |

---

## ✅ Requisitos

### Opção A — Docker (recomendado)

- **Docker** instalado
- **Docker Compose** instalado
- Conexão com a internet:
  - para baixar as imagens
  - para usar a API do DeepSeek Flash
  - **no primeiro uso**, para baixar o modelo de embeddings (arquivo grande, pode demorar)

### Opção B — Execução local (sem Docker)

- **Python 3.10+**
- **Qdrant** rodando localmente (via Docker individual ou binário)
- Conexão com a internet (mesmos motivos acima)
- **4 GB de RAM no mínimo** — **8 GB recomendado** (o modelo de embeddings + PyTorch consomem bastante memória)

---

## 📁 Estrutura esperada do projeto

> Os nomes abaixo são ilustrativos. Ajuste conforme a estrutura real do seu repositório.

```
.
├── app.py                 # aplicação Flask e rotas
├── ingest.py              # lógica de ingestão de PDFs
├── query.py               # lógica de recuperação e resposta
├── requirements.txt       # dependências Python
├── .env.example           # modelo de variáveis de ambiente
├── .env                   # variáveis reais (NÃO versionar)
├── docker-compose.yml     # sobe app + Qdrant
├── Dockerfile             # imagem da aplicação
├── static/                # CSS/JS da interface
└── templates/             # templates HTML da interface
```

---

## ⚙️ Variáveis de ambiente

Crie um arquivo `.env` na raiz do projeto. Exemplo:

```env
# Modelo de embeddings (local)
EMBEDDING_MODEL=intfloat/multilingual-e5-large

# API do modelo de chat (DeepSeek Flash via OpenCode)
OPENCODE_BASE_URL=https://sua-instancia.openCode...
OPENCODE_API_KEY=sua-chave-aqui

# Qdrant
QDRANT_URL=http://localhost:6333
QDRANT_COLLECTION=rag_docs

# Flask
PORT=5000
```

> ⚠️ **Atenção**
> - Não deixe `OPENCODE_API_KEY` exposta em repositório público.
> - Use `QDRANT_URL=http://qdrant:6333` quando a aplicação rodar dentro do Docker Compose (o nome do serviço substitui `localhost`).
> - Se usar **fora do Docker**, mantenha `QDRANT_URL=http://localhost:6333`.

---

## 🚀 Instalação e execução

> Nesta versão **não existe script `.sh`**. Todos os passos são executados manualmente, como descrito abaixo.

### Opção A — Com Docker Compose (recomendado)

1. **Clone o repositório e entre na pasta**

   ```bash
   git clone <url-do-repositorio>
   cd nome-do-projeto
   ```

2. **Crie o arquivo `.env`**

   ```bash
   cp .env.example .env
   nano .env
   ```

   Preencha com a chave da OpenCode e ajuste o nome da coleção, se necessário.

3. **Suba os serviços**

   ```bash
   docker compose up --build
   ```

   Na primeira execução:
   - a imagem da aplicação será construída;
   - o modelo de embeddings será baixado (pode demorar alguns minutos);
   - o Qdrant será iniciado junto.

4. **Acesse a interface**

   Abra no navegador:

   ```
   http://localhost:5000
   ```

5. **Para parar**

   ```bash
   Ctrl+C
   ```

   Ou, em segundo plano:

   ```bash
   docker compose up --build -d
   docker compose down
   ```

### Opção B — Sem Docker (ou apenas Qdrant separado)

1. **Subir o Qdrant individualmente** (se ainda não estiver rodando):

   ```bash
   docker run -d -p 6333:6333 \
     -v qdrant_data:/qdrant/storage \
     qdrant/qdrant
   ```

2. **Criar o ambiente Python**

   ```bash
   python -m venv venv
   source venv/bin/activate        # Linux/macOS
   # venv\Scripts\activate         # Windows
   ```

3. **Instalar as dependências**

   ```bash
   pip install -r requirements.txt
   ```

4. **Configurar o `.env`**

   ```bash
   cp .env.example .env
   nano .env
   ```

   Aqui o Qdrant deve apontar para `http://localhost:6333`.

5. **Executar a aplicação**

   ```bash
   python app.py
   ```

6. **Acessar**

   ```
   http://localhost:5000
   ```

---

## 🖥️ Utilização da interface Flask

A interface web é simples e tem dois fluxos principais:

### 1. Upload/ingestão de PDF

1. Clique no botão de **upload** ou selecione o arquivo PDF.
2. Escolha um ou mais arquivos `.pdf`.
3. Envie.

O que acontece nos bastidores:

- O Flask recebe o arquivo;
- o LangChain lê e divide o PDF em **chunks** (pedaços de texto);
- cada chunk recebe o prefixo `passage: `;
- o modelo de embeddings transforma cada chunk em vetor;
- o Qdrant armazena esses vetores na coleção configurada.

### 2. Pergunta ao sistema

1. Digite a pergunta no campo de texto.
2. Clique em **Perguntar** ou envie o formulário.

Bastidores:

- a pergunta recebe o prefixo `query: `;
- o Qdrant recupera os **8 trechos mais relevantes**;
- o LangChain monta o contexto;
- o DeepSeek Flash responde usando **apenas** esse contexto;
- a resposta aparece na tela.

---

## 🔁 Recriação da coleção e reingestão

> **Importante ao trocar de modelo de embeddings.**
> Vetores gerados com um modelo **não são compatíveis** com vetores de outro modelo.

Se você alterou `EMBEDDING_MODEL`, **limpe a coleção existente e reenvie todos os PDFs**.

### Como limpar a coleção

Substitua `NOME_DA_COLECAO` pelo valor real do seu `.env`:

```bash
docker compose run --rm app python -c "
from qdrant_client import QdrantClient
import os

client = QdrantClient(url=os.getenv('QDRANT_URL', 'http://localhost:6333'))
client.delete_collection(collection_name='NOME_DA_COLECAO')
print('Coleção removida. Reenvie os PDFs pela interface.')
"
```

Depois, volte na interface e **reenvie todos os PDFs** novamente.

---

## 🧪 Teste de validação

Depois de configurar e reingerir, faça este teste:

**Pergunta:**

> Um investidor aplicou R$ 1.000,00 a juros compostos de 10% ao ano. Qual será o montante após 2 anos?

**Resultado esperado:**

- O contexto deve incluir a fórmula `VF = VP × (1+i)^n`.
- A resposta deve ser **R$ 1.210,00**.

Se a resposta reclamar que a fórmula não está no contexto, verifique:

1. Se o modelo E5 está de fato ativo no `.env`.
2. Se os prefixos `passage: ` e `query: ` estão sendo aplicados.
3. Se `k` está em **8**.
4. Se a coleção foi realmente recriada após a troca de modelo.

---

## 🛠️ Solução de problemas comuns

| Sintoma | Causa provável | Correção |
|---|---|---|
| Erro de chave da OpenCode | `OPENCODE_API_KEY` ausente no `.env` | Confira o `.env` e reinicie a aplicação |
| Resposta "não encontrei no contexto" | `k` baixo, prefixos ausentes ou modelo antigo | Aumente `k`, confira prefixos, reingira os PDFs |
| Primeira pergunta muito lenta para responder | Modelo de embeddings carregando/cache ainda não quente | Aguarde; em seguida as consultas ficam rápidas |
| Erro de memória (Killed) | RAM insuficiente | Use máquina/container com 8 GB de RAM |
| PDF com texto quebrado/símbolos estranhos | Extração padrão não entende a fonte/equação | Teste trocar o loader por `PyMuPDFLoader` ou aceite a inferência do modelo |
| Coleção com vetores antigos | Troca de modelo sem reingestão | Apague a coleção e reenvie os PDFs |

---

## 🔒 Segurança

- **Nunca** versione o `.env`.
- Em produção/VPS, exponha o Qdrant **apenas internamente** (não publique a porta `6333` publicamente).
- Adicione autenticação na interface antes de expor o Flask à internet.
- Use HTTPS se for acessar fora da sua rede.

---

## 📌 Resumo rápido de comandos

```bash
# Docker Compose
cp .env.example .env
docker compose up --build

# Execução local (com Qdrant separado)
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python app.py

# Acesso
http://localhost:5000
```

---

## 📚 Referências dos modelos

- Embeddings: [`intfloat/multilingual-e5-large`](https://huggingface.co/intfloat/multilingual-e5-large)
- Banco vetorial: [Qdrant](https://qdrant.tech/)
- Modelo de chat: DeepSeek Flash via [OpenCode](https://opencode.ai/)
- Orquestração: [LangChain](https://python.langchain.com/)