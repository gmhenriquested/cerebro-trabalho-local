## Cérebro de trabalho

- Vault: `{{VAULT}}` (Obsidian + git). Regras em `{{VAULT}}\CLAUDE.md`. O hook SessionStart já injeta `memory/MEMORY.md` e `indice.md`.
- Memória durável vai **no vault** (`memory/`, um fato por arquivo, linha em `MEMORY.md`), não só no contexto. Decisão vira ADR em `decisoes/`.
- Antes de responder sobre projetos, pessoas ou decisões do trabalho, consulte o vault.
- Agentes: `curador`, `triagem`, `enriquecedor`, `ata`, `pesquisador`, `planejador`, `revisor-codigo`, `verificador`. Use subagentes para isolar contexto (pesquisa, revisão, verificação) e chame vários em paralelo quando forem independentes.
- Skills: `/capturar`, `/processar-inbox`, `/revisar-propostas`, `/nova-tarefa`, `/construir`.
- Código: para qualquer coisa não trivial, siga `/construir` (especificar, fatiar, verificar com evidência, revisar). Nunca diga "pronto" sem ter rodado a verificação.
- Loops e agentes autônomos só propõem (`propostas/`, `tarefas/`). Promover é com o dono presente.
- Dado da empresa não vai para buscas na web nem para repositórios públicos. Nunca grave segredo.
- Quando o dono corrigir algo que pode se repetir, salve a memória e sugira um caso em `evals/casos/`.
