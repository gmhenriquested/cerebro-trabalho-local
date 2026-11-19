# ADR 0005: execução autônoma por níveis, em worktree, sem merge automático

- **Status:** aceita
- **Data:** 2026-11-19

## Contexto
Agentes já conseguem implementar tarefas inteiras sozinhos, mas o risco cresce com o que eles podem tocar. Código feito com IA também tende a parecer certo sem estar.

## Decisão
- Tarefas ficam em `tarefas/` com critérios de pronto verificáveis. Só o dono libera (`status: pronta`).
- O executor trabalha num `git worktree` com branch `agente/<tarefa>`, com lista explícita de comandos.
- Níveis por repositório: 0 só plano, 1 branch local, 2 push da branch e PR em rascunho. Merge é sempre humano.
- A verificação roda fora do modelo; um revisor independente dá o veredito; há limite de tentativas e de turnos.

## Consequências
- **Limite honesto:** a lista de comandos não é menor privilégio de verdade. `npm test`, `npm run build` e `npx` executam scripts do repositório, que o agente pode editar. No nível 1, o executor consegue rodar código com o usuário do dono, e a guarda não vê esse código. Para isolar de verdade: WSL2 com o sandbox nativo do Claude Code, ou outro usuário do Windows sem credenciais de push. Até lá, use o executor só em repositórios em que você aceitaria esse risco.
- O agente só escreve dentro do worktree (`%LOCALAPPDATA%\cerebro\worktrees`); o contexto do vault vai inline, sem acesso ao vault.
- Começar pelo nível 0 e subir conforme o histórico de tarefas boas.
- Repositório sem testes rende pouco no executor: primeiro crie testes.
- Cada tarefa deixa relatório e retro, que alimentam o loop de reflexão.
