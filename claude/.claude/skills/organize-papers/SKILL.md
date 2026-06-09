---
name: organize-papers
description: Organiza a biblioteca de papers/dissertações no diretório atual — numera novos arquivos por dificuldade, renomeia para Autor(Ano)_título em inglês, e mantém o COMO_LER.md atualizado.
---

# organize-papers

Organiza a biblioteca de papers/dissertações neste diretório.

## Quando invocar

- `/organize-papers` — processa arquivos novos sem número e reorganiza a fila
- `/organize-papers read <número>` — marca um paper como lido (ex: `/organize-papers read 07`)

---

## Comportamento padrão (`/organize-papers`)

### 1. Levantamento

Liste todos os PDFs no diretório atual. Classifique cada um em três grupos:

- **Lidos** — prefixo `LIDO_` → ignorar completamente nesta execução
- **Na fila** — prefixo numérico `NN_` → já organizados, não mexer no nome
- **Novos** — sem prefixo numérico e sem `LIDO_` → precisam ser processados

Se não houver arquivos novos, informe e encerre.

### 2. Análise dos arquivos novos

Para cada arquivo novo, leia as primeiras páginas (abstract, resumo, sumário) e determine:

**Tipo de documento:**
- Artigo curto (≤10 páginas, ex: Science/Nature) → tende a ★★☆
- Artigo de pesquisa (10–30 páginas) → tende a ★★★
- Revisão sistemática / scoping review → tende a ★★★
- Artigo com ML/modelagem pesada → tende a ★★★★
- Dissertação ou tese → tende a ★★★★ (sempre mencionar que a estratégia de leitura é diferente)

**Dificuldade** (use exatamente um desses valores):
- ★★☆ — conceitual, pouco técnico, bom ponto de entrada
- ★★★ — técnico mas acessível, requer atenção nos métodos
- ★★★★ — denso, requer múltiplas passagens ou conhecimento prévio

Apresente ao usuário um resumo de cada arquivo novo:
- Nome atual do arquivo
- Título real (do PDF)
- Tipo
- Dificuldade proposta com justificativa em uma frase
- Com quais papers já numerados ele se conecta tematicamente

### 3. Perguntas ao usuário

Após a análise, pergunte em uma única mensagem:

1. A dificuldade proposta para cada novo arquivo está correta, ou quer ajustar alguma?
2. Algum deles faz parte de um projeto específico (TCC, dissertação, artigo em escrita)? Se sim, qual e qual a relevância dele para o projeto?
3. Algum deles tem prioridade e deve entrar antes de outros? (ex: "o 08 precisa ser lido antes do congresso X")

Aguarde a resposta antes de continuar.

### 4. Inserção e renomeação

Com as confirmações do usuário:

- Determine a posição correta de cada novo arquivo na sequência:
  - **Sem projeto específico:** ordem crescente de dificuldade; em caso de empate, prioridade declarada → depois ordem de adição
  - **Com projeto específico:** se o arquivo faz parte de um projeto em andamento (ex: TCC, dissertação, artigo que está escrevendo), agrupe-o com os outros do mesmo projeto e ordene por **relevância ao projeto** (mais central/urgente primeiro), independente da dificuldade
- Renomeie o arquivo para `NN_Autor(Ano)_título.pdf` onde:
  - `Autor` é o sobrenome do primeiro autor (use `et_al` se houver mais de um, ex: `Silva_et_al`)
  - `Ano` é o ano de publicação extraído do PDF
  - `título` é um descritivo conciso do conteúdo em inglês, snake_case, 2–4 palavras
  - Ex: `10_Silva(2023)_soil_carbon_remote_sensing.pdf`, `11_Smith_et_al(2021)_water_quality_ML.pdf`
- Se a inserção empurra arquivos existentes, renomeie os afetados incrementando o número
- Nunca renumere arquivos com prefixo `LIDO_`

### 5. Atualização do COMO_LER.md

Abra `COMO_LER.md` e atualize:

**Tabela de artigos** — adicione a nova linha na posição correta:

| # | Arquivo | Tema | Tipo | Dificuldade |
|---|---------|------|------|-------------|

**Cronograma** — adicione a semana correspondente ao final, estimando o tempo:
- ★★☆: ~1h
- ★★★: ~1h30
- ★★★★ artigo: ~2h
- ★★★★ dissertação: ~3h (com nota "ver estratégia de leitura para dissertações")

Se o arquivo for uma dissertação, adicione uma subseção em "Estratégias específicas" com o roteiro de páginas baseado no sumário lido.

---

## Comportamento `read <número>` (`/organize-papers read 07`)

1. Localize o arquivo com prefixo `07_` no diretório
2. Renomeie para `LIDO_07_nome_original.pdf`
3. No `COMO_LER.md`:
   - Remova a linha da tabela principal
   - Adicione ao final do arquivo, numa seção `## Lidos`, a linha com data de conclusão:
     ```
     | 07 | Smith_et_al(2020)_water_quality_ML | Qualidade da água + ML | Artigo | ★★★ | lido em DD mmm YYYY |
     ```
4. **Não renumere** nenhum outro arquivo — o gap no número é intencional e serve como referência histórica
5. Confirme o que foi feito em uma linha

---

## Regras fixas

- Nunca altere arquivos com prefixo `LIDO_` exceto quando o comando for `read`
- Nunca crie gaps artificiais na sequência — se inserir um paper no meio, empurre os seguintes
- O nome do arquivo segue `NN_Autor(Ano)_título.pdf`; extraia autor e ano do PDF — se não encontrar, pergunte ao usuário antes de renomear
- Sempre pergunte antes de renomear — nunca renomeie sem confirmação do usuário
- Se o PDF não abrir ou não tiver abstract legível, informe e peça que o usuário descreva o conteúdo
