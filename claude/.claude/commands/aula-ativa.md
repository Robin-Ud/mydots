# /aula-ativa

Skill para anotação ativa de aulas com slides em PDF, no padrão do vault Obsidian do usuário (`5 facul/`).

Dois modos: `criar` e `corrigir`. Leia os argumentos em `$ARGUMENTS` para determinar qual executar.

---

## Modo: criar

**Ativado quando:** argumentos não contêm `corrigir` (pode ou não conter caminhos).

**Objetivo:** gerar um arquivo de notas estruturado com perguntas ativas espalhadas, pronto para o aluno responder durante a aula — seguindo exatamente a convenção já usada nas outras notas do vault.

### Passo 1 — descobrir o PDF principal

Se $ARGUMENTS contiver um caminho de PDF explícito, use-o.

Caso contrário, liste os PDFs em `~/Downloads` ordenados por data de modificação (mais recente primeiro):

```bash
ls -t ~/Downloads/*.pdf 2>/dev/null | head -20
```

Mostre a lista numerada ao usuário e pergunte qual usar. Aguarde a resposta antes de continuar.

### Passo 2 — descobrir a convenção antes de escrever qualquer coisa

**Nunca invente formato.** Antes de decidir nome de arquivo, frontmatter ou qualquer estrutura, descubra o padrão real:

1. Determine a pasta de destino do `.md` (caminho `.md` em $ARGUMENTS, ou diretório de trabalho atual).
2. Liste os `.md` já existentes nessa pasta:
   ```bash
   ls "<dir_da_nota>"/*.md 2>/dev/null
   ```
3. **Se a pasta já tem notas**, leia pelo menos uma inteira (a mais recente) e extraia dela: frontmatter usado, como o professor é referenciado, se há tags no corpo, estilo de escrita (prosa vs. bullets), densidade de perguntas `[?]`, convenção de nome de arquivo.
4. **Se a pasta está vazia** (ex: primeira aula da disciplina), ela não tem exemplo próprio — **procure em pastas irmãs** dentro do mesmo nível (ex: outras disciplinas do mesmo semestre, ou do semestre anterior se existir):
   ```bash
   # a partir da pasta de destino, olhe 1–2 níveis acima e liste as disciplinas irmãs
   ls -d "<dir_da_nota>/.."/*/ 2>/dev/null
   ```
   Leia pelo menos uma nota de aula completa de uma disciplina irmã (não só o arquivo-índice) para capturar o padrão real de escrita, não apenas de nomenclatura.
5. Nunca prossiga para os próximos passos sem ter lido pelo menos um exemplo real (da própria pasta ou de uma irmã). Se literalmente não existir nenhuma nota em lugar nenhum do vault, aí sim use a convenção descrita nos Passos 3–8 abaixo como padrão default — mas isso deve ser exceção, não o caminho normal.

O restante deste modo descreve a convenção **default observada no vault** — use-a como ponto de partida, mas o que você leu no Passo 2 tem prioridade se divergir.

### Passo 3 — definir o arquivo de saída

**Nome do arquivo:** `<código-da-disciplina>.<índice-sequencial> <slug descritivo, minúsculo, com espaços>.md`

- `<código-da-disciplina>` é o prefixo da pasta (ex: pasta `6.5 algodão café e agroecologia` → código `6.5`).
- `<índice-sequencial>` começa em `0` e é o número de arquivos de aula (`X.Y.*`) já existentes na pasta, **excluindo** o arquivo-índice da disciplina (`X.Y Nome Da Disciplina.md`).
- O slug é derivado do título/tema principal do PDF, em minúsculas, com espaços (não kebab-case, não snake_case) — ex: `6.4.0 introducao genetica molecular.md`, `6.3.0 apresentação da disciplina, histoico importancia economica e custo de produção.md`.
- Se o PDF cobrir dois temas claramente distintos com capas/títulos próprios (comum quando o professor sobe um PDF único com "Parte 1" e "Parte 2"), **separe em duas notas** com índices sequenciais consecutivos (`X.Y.0`, `X.Y.1`), não uma nota única gigante.

```bash
ls "<dir_da_nota>"/*.md 2>/dev/null | grep -cE '^.*/[0-9]+\.[0-9]+\.[0-9]+ '
# esse número é o próximo índice sequencial
```

### Passo 4 — identificar professor e disciplina

**Disciplina:** nome da pasta de destino, convertido para `CamelCase` sem espaços/acentos para o campo `disciplina:` do frontmatter (ex: pasta `6.5 algodão café e agroecologia` → `AlgodaoCafeEAgroecologia`).

**Professor:** descubra automaticamente nesta ordem:

1. Verifique se o nome do professor aparece no texto extraído do PDF (capa, cabeçalhos, rodapés).
2. Se não, procure um wikilink já usado para ele nas notas existentes (da própria pasta ou de pasta irmã):
   ```bash
   grep -roh "\[\[4 pessoas/professores-palestrantes/[^]]*\]\]" "<dir_da_nota>/.." --include="*.md" 2>/dev/null | sort -u | head -10
   ```
3. Só pergunte ao usuário se nenhuma busca retornar resultado.

Referencie o professor com **wikilink completo**, nunca com hashtag:
```
[[4 pessoas/professores-palestrantes/Nome Completo Do Professor]]
```
logo após o frontmatter, antes do título. Se o arquivo de ficha do professor (`4 pessoas/professores-palestrantes/Nome Completo.md`) ainda não existir, crie-o no Passo 8.

### Passo 5 — extrair texto

```bash
pdftotext "<caminho_do_pdf>" - 2>/dev/null
```

Se o texto extraído for insuficiente (slides muito visuais, diagramas), use o Read tool nas páginas específicas — mas só quando necessário.

### Passo 6 — armazenar as fontes

Crie `.fontes/` na pasta de destino e copie o PDF com nome no padrão `<NN>_aula_<slug_com_underscore>.pdf` (numeração própria da fonte, não do índice da nota — dois dígitos, começando em `01`):

```bash
mkdir -p "<dir_da_nota>/.fontes"
cp "<caminho_do_pdf>" "<dir_da_nota>/.fontes/<NN>_aula_<slug_com_underscore>.pdf"
# ex: .fontes/02_aula_higiene_legislacao.pdf
```

Pergunte ao usuário: **"Há outros arquivos do professor em ~/Downloads para incluir nessa nota? (apostilas, exercícios, fórmulas)"**

Se sim:
1. Liste `~/Downloads` e mostre ao usuário
2. Aguarde ele identificar quais incluir
3. Para cada extra, copie para `.fontes/<NN>_extra_<slug_com_underscore>.<ext>` (ex: `04_extra_absorcao_nutrientes_folha.pdf`) e extraia o conteúdo (`pdftotext` para PDFs, Read para imagens)
4. Use os extras para enriquecer o texto da nota onde o material se encaixar; não é necessário criar seção separada — integre ao fluxo.

### Passo 7 — construir as notas

O estilo real do vault é **prosa sintética e densa**, não transcrição de slide. Escreva como quem já entendeu a aula e está resumindo pra si mesmo, não como quem está copiando tópicos:

- Combine informações relacionadas em parágrafos corridos em vez de bullet por número de slide. Uma tabela só quando o dado é genuinamente tabular (cronograma, notas de avaliação, comparação numérica entre categorias) — não crie uma tabela pra cada bloco de slide.
- Corte redundância agressivamente: se três slides seguidos dizem variações da mesma ideia, isso vira um parágrafo, não três seções.
- Fórmulas e citações diretas importantes ficam em blockquote `>` ou bloco de código.
- Diagramas de fluxo/estrutura simples podem virar ASCII quando ajudam a entender uma hierarquia (ex: estrutura de nós/ramos).
- Separe blocos temáticos maiores com `---`.
- Termine com `## Ação para próxima aula` **somente se houver itens reais pendentes** (leitura indicada, tarefa de laboratório/canteiro, prazo de entrega) — formato checklist `- [ ]`. Não invente itens genéricos.

### Passo 8 — inserir perguntas ativas

As perguntas `[?]` são **poucas e cirúrgicas** — o padrão real do vault usa algo como 2 a 6 perguntas por nota inteira (não uma por seção). Reserve-as para os pontos de maior densidade conceitual, onde entender o "porquê" importa mais que decorar o número do slide.

Tipos possíveis: conceitual ("por que X acontece"), aplicação, previsão, comparação, cálculo (se houver fórmula), verdadeiro/falso com justificativa. A pergunta deve forçar o aluno a processar algo que o slide não entrega pronto — nunca pergunte o que já está escrito literalmente no texto.

Formato: `> **[?]** <pergunta>`, deixando espaço em branco logo abaixo (linha vazia) para a resposta do aluno.

### Passo 9 — salvar o arquivo

Estrutura obrigatória no início de cada nota:

```markdown
---
disciplina: NomeDaDisciplinaEmCamelCase
data: "[[AA-MM-DD]]"
---

[[4 pessoas/professores-palestrantes/Nome Completo Do Professor]]

# <título da aula>
```

- `disciplina:` no frontmatter é **obrigatório**. `data:` é opcional (inclua quando a aula tem data clara, no formato `AA-MM-DD` casando com as daily notes do vault, ex: `26-08-12`).
- **Nunca use `#hashtags` no corpo** — nem para disciplina, nem para professor. A referência ao professor é sempre o wikilink do Passo 4.
- Se `4 pessoas/professores-palestrantes/Nome Completo.md` ainda não existe, crie-o com:
  ```markdown
  ---
  tipo: pessoa
  ---

  ## areas do conhecimento



  ## disciplinas

  ### prof unico

  - [[<caminho>/<X.Y> Nome Da Disciplina|Nome Da Disciplina]]

  ### participação dividida


  ### prof visitante


  ## informações estratégicas

  ### qualidade de aula


  ### estilo e dificuldade de avaliação


  ## artigos lidos


  ## notas

  ```
- Se o arquivo-índice da disciplina `<X.Y> Nome Da Disciplina.md` (na raiz da pasta, nome capitalizado) ainda não existe, crie-o:
  ```markdown
  ---
  disciplina: NomeDaDisciplinaEmCamelCase
  ---

  [[4 pessoas/professores-palestrantes/Nome Completo Do Professor]]

  # Nome Da Disciplina
  > Prof. Nome Completo Do Professor

  ## Aulas
  - [[<caminho completo>/<X.Y.0> <slug>|<X.Y.0> <slug>]]

  ## Todas as notas (auto)
  \`\`\`base
  filters:
    and:
      - 'disciplina == "NomeDaDisciplinaEmCamelCase"'
  views:
    - type: table
      name: "Todas"
      order:
        - file.name
  \`\`\`
  ```
  Se o arquivo já existe, apenas adicione a nova aula à lista em `## Aulas`.

Salve e informe ao usuário os caminhos de tudo que foi criado ou atualizado (nota(s) de aula, `.fontes/`, ficha do professor se nova, índice da disciplina se novo/atualizado).

---

## Modo: corrigir

**Ativado quando:** argumentos contêm `corrigir`.

Se um caminho de arquivo for fornecido, use-o. Se não, procure o `.md` mais recentemente modificado no diretório de trabalho atual (ignorando o arquivo-índice da disciplina).

**Objetivo:** fechar o ciclo da aula — corrigir escrita, avaliar respostas, arrematar o arquivo.

### O que fazer

1. **Corrigir ortografia e gramática** em todo o arquivo — incluindo nas notas inline do aluno. Preserve o tom e a voz do aluno, só corrija erros.

2. **Avaliar cada resposta dada** a perguntas `[?]`:
   - Dê uma nota de **0 a 10**
   - Explique brevemente o que estava certo, o que faltou, e qual seria a resposta completa
   - Se a pergunta ficou sem resposta, deixe-a aberta (não responda por ele)
   - Formato: adicione a avaliação como linha(s) após a resposta do aluno, dentro do mesmo blockquote

3. **Limpar notas soltas** do aluno — integre observações espalhadas ao fluxo do texto quando fizerem sentido, ou deixe como nota indentada se forem dúvidas abertas

4. Salve o arquivo com as correções.

---

## Observações gerais

- **Nunca invente convenção sem checar exemplos reais primeiro** (Passo 2) — isso vale mais que qualquer default descrito aqui.
- Frontmatter `disciplina:` é obrigatório; `#hashtags` no corpo nunca são usados neste vault.
- O professor é sempre referenciado por wikilink, nunca por hashtag.
- Não crie arquivos de planejamento nem documentos intermediários — trabalhe direto nos arquivos finais (nota, índice da disciplina, ficha do professor).
- Seja conciso nas avaliações do modo `corrigir`: o aluno está revisando, não lendo um ensaio.
- A pasta `.fontes/` é oculta por ponto — não precisa aparecer nas notas, só arquiva as fontes originais.
- Perguntas `[?]` são poucas e de alto valor — nunca uma por seção só para preencher.
