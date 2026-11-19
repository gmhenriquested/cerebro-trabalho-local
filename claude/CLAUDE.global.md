## Cérebro de trabalho

- Vault: `{{VAULT}}` (Obsidian + git). Regras em `{{VAULT}}\CLAUDE.md`. O hook SessionStart já injeta `memory/MEMORY.md` e `indice.md`.
- Memória durável vai **no vault** (`memory/`, um fato por arquivo, linha em `MEMORY.md`). Decisão vira ADR em `decisoes/`. Salve quando for óbvio, sem interromper o dono: um colhedor em segundo plano lê a conversa e guarda o que escapar.
- O dono não roda rituais. Se o SessionStart pedir revisão de um clique, faça depois da primeira tarefa, numa pergunta só, e não insista.
- Antes de responder sobre projetos, pessoas ou decisões do trabalho, consulte o vault.
- Agentes: `curador`, `triagem`, `enriquecedor`, `ata`, `pesquisador`, `planejador`, `revisor-codigo`, `verificador`. Use subagentes para isolar contexto (pesquisa, revisão, verificação) e chame vários em paralelo quando forem independentes.
- Skills: `/capturar`, `/processar-inbox`, `/revisar-propostas`, `/nova-tarefa`, `/construir`.
- Código: para qualquer coisa não trivial, siga `/construir` (especificar, fatiar, verificar com evidência, revisar). Nunca diga "pronto" sem ter rodado a verificação.
- O automático aplica só o que é de baixo risco (status, notas, inbox, tarefas em rascunho, índices). Memória sobre o dono, ADR, agentes, skills e regras são proposta.
- Dado da empresa não vai para buscas na web nem para repositórios públicos. Nunca grave segredo.
- Quando o dono corrigir algo que pode se repetir, salve a memória e sugira um caso em `evals/casos/`.
