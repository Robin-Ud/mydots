# /aula-ativa

Skill para anotação ativa de aulas com slides em PDF.

Dois modos: `criar` e `corrigir`. Leia os argumentos em `$ARGUMENTS` para determinar qual executar.

---

## Modo: criar

**Ativado quando:** argumentos não contêm `corrigir` (pode ou não conter caminhos).

**Objetivo:** gerar um arquivo de notas estruturado com perguntas ativas espalhadas, pronto para o aluno responder durante a aula.

### Passo 1 — descobrir o PDF principal

Se $ARGUMENTS contiver um caminho de PDF explícito, use-o.

Caso contrário, liste os PDFs em `~/Downloads` ordenados por data de modificação (mais recente primeiro):

```bash
ls -t ~/Downloads/*.pdf 2>/dev/null | head -20
```

Mostre a lista numerada ao usuário e pergunte qual usar. Aguarde a resposta antes de continuar.

### Passo 2 — definir o arquivo de saída

Determine a pasta de destino e o nome do `.md`:
- Se $ARGUMENTS contiver um caminho `.md`, use-o
- Caso contrário, use o diretório de trabalho atual

O **código numérico da aula** é o número de arquivos `.md` já existentes na pasta + 1, com zero à esquerda:

```bash
printf "%02d" $(( $(ls "<dir_da_nota>"/*.md 2>/dev/null | wc -l) + 1 ))
# ex: 01, 02, 13
```

O **nome descritivo** do arquivo será derivado do conteúdo do PDF no Passo 4 (após extração do texto). Por ora, use um placeholder — o nome final do `.md` será `<código>_<nome-descritivo>.md`.

### Passo 3 — identificar professor e disciplina

**Disciplina:** use sempre o nome da pasta de destino do `.md`. Nunca pergunte ao usuário.

**Professor:** descubra automaticamente nesta ordem:

1. Verifique se o nome do professor aparece no texto extraído do PDF (capa, cabeçalhos, rodapés)
2. Se não, busque a tag `#Prof...` nos outros `.md` da mesma pasta:
   ```bash
   grep -roh "#Prof[A-Z][A-Za-z]*" "<dir_da_nota>/" --include="*.md" 2>/dev/null | sort -u | head -5
   ```
3. Se não, leia as primeiras 5 linhas de cada `.md` da pasta em busca do padrão `#Prof`
4. Só pergunte ao usuário se nenhuma busca retornar resultado

O nome deve estar **completo** e no formato `#ProfNomeCompletoEmCamelCase` (ex: `#ProfThiagoLiborioRomanelli`). Nunca abrevie.

### Passo 4 — extrair texto e derivar nome descritivo

Extraia o texto do PDF original:

```bash
pdftotext "<caminho_do_pdf>" - 2>/dev/null
```

Se o texto extraído for insuficiente (slides muito visuais, diagramas), use o Read tool nas páginas específicas — mas só quando necessário.

Com base no conteúdo extraído, derive um **nome descritivo em kebab-case** a partir do título do primeiro slide ou tema principal (ex: `introducao-ao-transistor-bipolar`). Ignore completamente o nome original do arquivo do professor.

### Passo 5 — armazenar as fontes

Crie `.fontes/` na pasta de destino e copie o PDF renomeado:

```bash
mkdir -p "<dir_da_nota>/.fontes"
cp "<caminho_do_pdf>" "<dir_da_nota>/.fontes/<código>_<nome-descritivo>.pdf"
# ex: .fontes/03_introducao-ao-transistor-bipolar.pdf
```

Pergunte ao usuário: **"Há outros arquivos do professor em ~/Downloads para incluir nessa nota? (apostilas, exercícios, fórmulas)"**

Se sim:
1. Liste `~/Downloads` e mostre ao usuário
2. Aguarde ele identificar quais incluir
3. Para cada extra:
   - Copie para `.fontes/<código>_extra_<n>.<ext>` (ex: `03_extra_1.pdf`)
   - Extraia o conteúdo (`pdftotext` para PDFs, Read para imagens)
4. Use os extras para enriquecer seções da nota onde o material se encaixar, adicionar uma seção `## Materiais Complementares` ao final e gerar perguntas `> **[?]**` sobre pontos que podem surgir em sala

### Passo 6 — construir as notas

- Anote **tudo que for relevante**, mesmo o que pareça óbvio — o aluno não deve precisar copiar nada durante a aula
- Mantenha a estrutura dos slides (seções, hierarquia)
- Use tabelas, listas e fórmulas quando o conteúdo pedir
- Preserve citações diretas importantes em blockquote `>`
- Para diagramas de fluxo/circuitos, represente em ASCII simples

### Passo 7 — inserir perguntas ativas

Espalhe perguntas `> **[?]**` ao longo das notas — pelo menos uma por seção, mais em seções densas. Varie o tipo conforme o conteúdo:

- **Conceitual:** "O que é X? Por que Y acontece?"
- **Aplicação:** "Em qual situação usaríamos X em vez de Y?"
- **Previsão:** "O que acontece se X falhar / for alterado?"
- **Comparação:** "Qual a diferença entre X e Y?"
- **Cálculo:** se houver fórmulas, peça um exemplo numérico simples
- **Verdadeiro/Falso:** afirmações para o aluno marcar e justificar

As perguntas devem forçar o aluno a prestar atenção em algo que o slide não entrega de bandeja. Não pergunte o que já está escrito no slide.

### Passo 8 — salvar o arquivo

Nome final do arquivo: `<código>_<nome-descritivo>.md` (ex: `03_introducao-ao-transistor-bipolar.md`).

O arquivo deve começar com:

```markdown
# <título da aula>

#<slug-da-disciplina> #Prof<NomeCompletoEmCamelCase>

---
```

As duas tags são **obrigatórias** e ficam no corpo logo abaixo do título. YAML frontmatter é opcional — só adicione se o aluno já usar ou pedir.

Salve e informe o caminho do `.md` e o conteúdo de `.fontes/`.

---

## Modo: corrigir

**Ativado quando:** argumentos contêm `corrigir`.

Se um caminho de arquivo for fornecido, use-o. Se não, procure o `.md` mais recentemente modificado no diretório de trabalho atual.

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

- As tags `#disciplina` e `#ProfNome` no corpo são obrigatórias — YAML é opcional
- Não crie arquivos de planejamento nem documentos intermediários — trabalhe direto no arquivo final
- Seja conciso nas avaliações: o aluno está revisando, não lendo um ensaio
- A pasta `.fontes/` é oculta por ponto — não precisa aparecer nas notas, só arquiva as fontes originais
