# /estudo-ativo

Skill para estudo intenso de matérias que exigem raciocínio e resolução de problemas — física, química, estatística e similares.

Argumentos em `$ARGUMENTS`: matéria + período + modo (opcional).
Exemplos:
- `fisica p3` → constrói pasta de revisão completa
- `quimica p1 sessao` → sessão interativa guiada
- `estatistica p2 simulado` → só gera o simulado (pasta já existe)

---

## Modo padrão — construir pasta de revisão

Ativado quando não há argumento `sessao`. Produz 4 arquivos prontos para estudar sozinho.

### Passo 1 — localizar e ler TODO o material

**Não crie nada antes de terminar a leitura completa.**

Caminhos a verificar, nesta ordem:
0. **Índice de fontes já arquivadas:** verifique se existe `<pasta_destino>/.fontes/INDICE.md`. Se existir, leia-o antes de copiar qualquer PDF — a coluna "Caminho original" lista os arquivos já arquivados. Ao encontrar um PDF em `~/Downloads`, compare o caminho completo com essa coluna: se já estiver no índice, **não copie de novo** (o arquivo já está em `.fontes/` com o nome renomeado). Isso evita duplicatas sem impedir o re-scan normal do diretório.
1. Notas do vault: `/home/rud/obsidian/5 facul/5 semestre/` — subpasta da matéria e período
   - `quimica` → `5.0 quimica/`
   - `fisica` → `5.1 fisica do ambiente/`
   - `estatistica` → `5.3 estatica/`
2. PDFs em `~/Downloads/` — procure com `find ~/Downloads -name "*.pdf" -newer /tmp` ou liste e filtre pelo nome da matéria. Leia com o Read tool (use `pages` para não desperdiçar tokens em PDFs longos — leia em blocos de 10-15 páginas).
3. Se houver listas de exercícios com gabarito, identifique-as explicitamente — serão a base dos arquivos de exercícios.


O que extrair da leitura:
- Todas as equações e constantes usadas pelo professor (não as genéricas do livro)
- Os tipos de problema que aparecem nas listas
- Erros comuns mencionados em dicas ou comentários do professor
- Quais tópicos têm mais exercícios (= mais prováveis na prova)


### Passo 2 — resolver e verificar todos os exercícios das listas

Para cada exercício das listas encontradas:
- Resolva completamente, mostrando contas intermediárias
- Compare com o gabarito se disponível — se não fechar, investigue antes de prosseguir
- Anote questões sem gabarito para sinalizar no arquivo

### Passo 3 — arquivar as fontes em `.fontes/`

Antes de criar qualquer arquivo, determine a pasta de destino no vault (matéria + período) e crie a subpasta `.fontes/` dentro dela.

**Verifique o índice antes de copiar qualquer arquivo.** Se `.fontes/INDICE.md` já existir, leia-o — ele lista os PDFs já arquivados com seus caminhos originais. Pule arquivos que já constam no índice; apenas adicione os novos.

Para cada PDF novo encontrado no Passo 1:

1. Atribua um número sequencial (`01`, `02`, …) continuando da última entrada do índice (ou começando em `01` se não existir).
2. Derive um slug curto do conteúdo do arquivo (ex: `psicrometria`, `agua_no_solo`, `exercicios_lista3`).
3. Copie com o nome renomeado:

```bash
mkdir -p "<pasta_destino>/.fontes/"
cp "<caminho_original>" "<pasta_destino>/.fontes/NN_slug.pdf"
```

4. Acrescente uma linha ao `INDICE.md` (crie o arquivo se não existir):

```markdown
| NN | NN_slug.pdf | /caminho/original/arquivo.pdf | breve descrição do conteúdo |
```

O `INDICE.md` deve ter cabeçalho fixo:

```markdown
# Índice de fontes

| # | Arquivo em .fontes/ | Caminho original | Conteúdo |
|---|---------------------|------------------|----------|
```

Faça isso para cada PDF relevante encontrado. Se a pasta de destino ainda não existir, crie-a junto com `.fontes/`.

---

### Passo 4 — criar os 4 arquivos

Salve na pasta do vault da matéria/período. Se a pasta não existir, crie-a.

---

#### `formulas.md` — cheatsheet de referência rápida

- Todas as equações organizadas por tópico
- Tabela de constantes com variação por sistema de unidades (quando aplicável)
- Alertas sobre erros comuns: unidades, sinais, casos especiais, armadilhas que o professor mencionou
- Um "macete de resolução" por tipo de problema — fluxograma textual dos passos para atacar cada categoria

---

#### `diagnostico.md` — mapa de gaps

8 a 12 perguntas curtas cobrindo os tópicos do período. Uma por tópico, variando o tipo:
- Conceitual: "O que significa fisicamente X?"
- Cálculo rápido: valor numérico, unidade correta
- Interpretação: dado um resultado, o que ele implica?
- Verdadeiro/Falso com justificativa obrigatória

Cada pergunta tem gabarito logo abaixo, separado por `---`. O aluno responde no arquivo (ou no papel) antes de olhar.

Ao final, inclua uma tabela de mapeamento:
| Questão | Tópico | Se errou, revisar em |
|---------|--------|----------------------|
| Q1 | ... | formulas.md § X |

---

#### `exercicios_[topico].md` — um arquivo por categoria de conteúdo

Se o período tiver dois temas distintos (ex: psicrometria + água no solo), crie dois arquivos separados.

Estrutura de cada arquivo:
- Exercícios ordenados por dificuldade: ⭐ básico → ⭐⭐ médio → ⭐⭐⭐ difícil
- Cada exercício: enunciado completo + passo a passo com contas intermediárias + resultado em destaque + gabarito oficial para conferência (ou `[sem gabarito]` quando não houver)
- Para questões dissertativas: resposta completa com argumentos e conexão com a prática agronômica

---

#### `simulado.md` — prova nova, criada do zero

5 a 6 questões **inéditas** (não cópias das listas).

Regras de composição:
- Alta dificuldade geral
- Conteúdo e tipos **fora de ordem** — não agrupe por tópico, misture como numa prova real
- Tipos misturados: (C) cálculo, (V/F) verdadeiro/falso com justificativa, (D) dissertativa
- Pelo menos uma questão que combine dois tópicos do período
- Gabarito completo no final do arquivo

---

### Regras de qualidade para todos os arquivos

- Verifique numericamente todas as contas antes de escrever o gabarito
- Se um exercício depender de figura que não dá para reconstruir completamente, explique o método e apresente a resposta do gabarito sem inventar a geometria
- Não use fórmulas que não estejam nos materiais fornecidos pelo professor
- Sem texto de preenchimento — cada linha deve ser útil na véspera da prova
- Escreva tudo em português brasileiro

---

## Modo `sessao` — estudo interativo guiado

Ativado com argumento `sessao`. Usa os arquivos da pasta de revisão se já existirem; caso contrário, trabalha diretamente com as notas do vault.

### Fluxo

1. **Diagnóstico rápido** (3 a 5 perguntas sobre os conceitos centrais). Avalie as respostas e mapeie onde estão os gaps — esses serão o foco da sessão. Se o aluno já fez o `diagnostico.md`, peça para reportar quais questões errou e pule direto para os gaps.

2. **Para cada gap identificado:**
   - Explique o conceito com foco no mecanismo (por que funciona assim), não só na definição
   - Mostre um exemplo resolvido passo a passo com unidades explícitas
   - Proponha um exercício similar — espere a resposta antes de continuar
   - Corrija e explique onde o raciocínio desviou. Se acertou, proponha variação mais difícil

3. **Não avance para o próximo conceito antes de demonstrar entendimento do atual.**

4. Ao final, resumo em 3 a 5 linhas: o que ficou sólido, o que ainda precisa de atenção.

### Regras da sessão

- Não entregue respostas sem o aluno tentar. Se pedir a resposta antes de tentar, ofereça uma dica ou quebre o problema em partes menores.
- Para física e química: sempre trabalhe com unidades explícitas. Erros de unidade são erros de raciocínio.
- Para estatística: antes de qualquer cálculo, peça ao aluno para identificar a variável, o teste/distribuição e as hipóteses. Erro de escolha de ferramenta é mais grave que erro de conta.

---

## Modo `simulado` — só gera o simulado

Ativa quando o argumento contém `simulado` mas não `sessao`. Lê o material existente e gera apenas o `simulado.md` seguindo as mesmas regras do modo padrão. Útil quando a pasta já existe mas o simulado precisa ser renovado antes da prova.
