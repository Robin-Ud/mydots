# Regras gerais (todos os projetos do Matheus)

## Commits
Projeto acompanhado é projeto commitado: o histórico é a documentação de como
ele chegou onde está.

- **Conventional Commits**: `tipo(escopo): descrição`. Tipo em inglês; descrição
  e corpo em português, com acento.
- Tipos: `feat`, `fix`, `refactor`, `style`, `docs`, `test`, `perf`, `chore` e
  **`content`** = conteúdo que o programa usa (puzzles, fichas, cards, textos).
- Escopo = a área ou funcionalidade, nunca o nome do arquivo. Cada projeto lista
  os seus escopos no CLAUDE.md dele; commit que mexe em tudo vai sem escopo.
- Título até ~60 caracteres, minúsculo, sem ponto final. Linha em branco. Corpo
  diz o **porquê** (o quê o diff já mostra), quebrado em ~72.
- **Atômico**: um assunto por commit, e cada commit passa nos testes sozinho.
  Estilo/refatoração nunca no mesmo commit que mudança de comportamento.
- **Commitar a cada passo que funciona**, não só no fim: pode commitar sem pedir.
  Achou trabalho acumulado sem commit → separar em commits atômicos (testando
  cada versão intermediária) antes de seguir.
- Mudou comportamento → README/CLAUDE.md do projeto no **mesmo** commit.
- Push e reescrever histórico já publicado só quando ele pedir (amigos atualizam
  com `pull --ff-only`). Antes de reescrever: branch de backup.
- Repo público: e-mail noreply do GitHub, nunca o gmail.
- No modo tutor quem commita é ele; eu reviso a mensagem.
