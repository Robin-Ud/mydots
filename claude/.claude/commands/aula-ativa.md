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

### Passo 2 — identificar professor e disciplina

**Disciplina:** use sempre o nome da pasta onde o arquivo `.md` será salvo (definida no Passo 3). Nunca pergunte ao usuário.

**Professor:** tente descobrir automaticamente nesta ordem:

1. Verifique se o nome do professor aparece no texto extraído do PDF (cabeçalhos, rodapés, capa)
2. Se não, leia as tags `#Prof...` dos outros arquivos `.md` na mesma pasta:
   ```bash
   grep -roh "#Prof[A-Z][A-Za-z]*" "<dir_da_nota>/" --include="*.md" 2>/dev/null | sort -u | head -5
   ```
3. Se não, leia os primeiros 5 linhas de cada `.md` da pasta em busca de padrão `#Prof`
4. Só pergunte ao usuário se nenhuma das buscas retornar resultado

O nome do professor deve estar **completo** e no formato `#ProfNomeCompletoEmCamelCase` (ex: `#ProfThiagoLiborioRomanelli`). Nunca abrevie.

Esses dados serão usados no Passo 7.

### Passo 3 — definir o arquivo de saída e armazenar a fonte

Determine o caminho do arquivo `.md` de saída:
- Se $ARGUMENTS contiver um caminho `.md`, use-o
- Caso contrário, use o diretório de trabalho atual com o nome do PDF convertido para `.md`

O **código da nota** é o nome do arquivo `.md` sem extensão (ex: `2026-06-09_circuitos`).

Crie a pasta `.fontes/` no mesmo diretório do `.md` e copie o PDF principal para lá, renomeando-o:

```bash
mkdir -p "<dir_da_nota>/.fontes"
cp "<caminho_do_pdf>" "<dir_da_nota>/.fontes/<código_da_nota>_slide.pdf"
```

### Passo 4 — arquivos adicionais

Pergunte ao usuário: **"Há outros arquivos do professor em ~/Downloads para incluir nessa nota? (ex: apostilas, exercícios, fórmulas)"**

Se o usuário confirmar (sim / listar nomes / dizer "sim, veja lá"):

1. Liste o conteúdo de `~/Downloads` e mostre ao usuário
2. Aguarde ele identificar quais arquivos incluir
3. Para cada arquivo extra selecionado:
   - Copie para `.fontes/<código_da_nota>_extra_<n>.<ext>`
   - Extraia o conteúdo (use `pdftotext` para PDFs, Read para imagens)
4. Use o conteúdo dos extras para:
   - Enriquecer seções da nota onde o material se encaixar
   - Adicionar uma seção `## Materiais Complementares` ao final com pontos-chave dos extras
   - Gerar perguntas `> **[?]**` específicas sobre o material extra — especialmente questões que podem surgir em sala a partir desses materiais

Se o usuário disser não ou ignorar, prossiga apenas com o PDF principal.

### Passo 5 — extrair texto dos PDFs com eficiência de tokens

Use Bash com `pdftotext` para extrair o texto completo do PDF principal antes de qualquer coisa:

```bash
pdftotext "<dir_da_nota>/.fontes/<código_da_nota>_slide.pdf" - 2>/dev/null
```

Se o texto extraído for insuficiente em alguma seção (slides muito visuais, diagramas, tabelas), use o Read tool com `pages` específicas para ver aquelas páginas como imagem — mas só quando necessário.

### Passo 5 — construir as notas

- Anote **tudo que for relevante**, mesmo o que pareça óbvio — o aluno não deve precisar copiar nada durante a aula
- Mantenha a estrutura dos slides (seções, hierarquia)
- Use tabelas, listas e fórmulas quando o conteúdo pedir
- Preserve citações diretas importantes em blockquote `>`
- Para diagramas de fluxo/circuitos, tente representar em texto ASCII simples

### Passo 6 — inserir perguntas ativas

Espalhe perguntas `> **[?]**` ao longo das notas — pelo menos uma por seção, mais em seções densas. Varie o tipo conforme o conteúdo:

- **Conceitual:** "O que é X? Por que Y acontece?"
- **Aplicação:** "Em qual situação usaríamos X em vez de Y?"
- **Previsão:** "O que acontece se X falhar / for alterado?"
- **Comparação:** "Qual a diferença entre X e Y?"
- **Cálculo:** se houver fórmulas, peça um exemplo numérico simples
- **Verdadeiro/Falso:** afirmações para o aluno marcar e justificar

As perguntas devem forçar o aluno a prestar atenção em algo que o slide não entrega de bandeja. Não pergunte o que já está escrito no slide.

### Passo 7 — salvar o arquivo

O arquivo deve começar com:

```markdown
# <título da aula ou nome do PDF limpo>

#<slug-da-disciplina> #Prof<NomeCompletoEmCamelCase>

---
```

As duas tags (`#disciplina` e `#prof/nome`) são **obrigatórias** e devem ficar no corpo logo abaixo do título, visíveis em qualquer visualizador. YAML frontmatter é opcional — só adicione se o aluno já usar ou pedir.

Salve no caminho definido no Passo 3. Informe o caminho salvo e liste o conteúdo de `.fontes/`.

---

## Modo: corrigir

**Ativado quando:** argumentos contêm `corrigir`.

Se um caminho de arquivo for fornecido, use-o. Se não, procure o arquivo `.md` mais recentemente modificado no diretório de trabalho atual.

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

- As tags `#disciplina` e `#prof/nome` no corpo são obrigatórias — YAML é opcional
- Não crie arquivos de planejamento nem documentos intermediários — trabalhe direto no arquivo final
- Seja conciso nas avaliações: o aluno está revisando, não lendo um ensaio
- A pasta `.fontes/` é oculta por ponto — não precisa aparecer nas notas, só serve de arquivo das fontes originais
