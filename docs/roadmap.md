# Roadmap

Ordem sugerida. Ligue uma etapa, use por alguns dias, só então siga.

## Etapa 1: base (dia 1)
- [ ] Instalar, abrir o vault no Obsidian e (opcional) ligar um remoto privado.
- [ ] Preencher `pessoas/`, `projetos/` e `referencias/` com o básico.
- [ ] Conferir que o SessionStart injeta o contexto, o colhedor grava algo depois de uns 8 turnos, o sync faz commit e a guarda bloqueia um `git push --force` de teste.

## Etapa 2: agentes e vibe coding (semana 1)
- [ ] Usar `/capturar`, o agente `ata` e `/construir` no dia a dia.
- [ ] Criar `CLAUDE.md` nos repositórios principais a partir de `templates/CLAUDE-projeto.md`.
- [ ] Criar 1 ou 2 agentes do stack da empresa (no vault ou em `.claude/agents/` do repo, não no kit).

## Etapa 3: loops (semana 2)
- [ ] Ver o que o colhedor gravou sozinho na primeira semana (`propostas/*-colhedor-*.md`) e ajustar `prompts/colhedor.md` se gravar demais ou de menos.
- [ ] Ligar a reflexão; aprovar as propostas pela revisão de um clique.
- [ ] Ligar o noturno e o semanal.
- [ ] Ajustar os prompts em `prompts/` conforme as propostas ruins.

## Etapa 4: grafo e evals (semana 3)
- [ ] Rodar `/processar-inbox` com o inbox cheio.
- [ ] Ter pelo menos 5 casos em `evals/casos/` vindos de correções reais. Rodar o semanal com `-ComEvals`.

## Etapa 5: autonomia (semana 4)
- [ ] Escolher um repositório com testes bons. Configurar em `config/cerebro.json` com nível 0.
- [ ] Rodar 3 tarefas pequenas com `executor.ps1 -Tarefa <nome>` e ler os relatórios.
- [ ] Subir para nível 1 e ligar `executor.ativo`. Nível 2 só depois de umas 10 tarefas boas.

## Ideias para depois
- **Paralelismo:** `max_tarefas_por_rodada` maior roda em sequência; para paralelo, um processo por worktree (os worktrees já isolam).
- **Memória nativa no vault:** junction (`mklink /J`) da pasta de memória do Claude Code para `memory/` do vault, como no cérebro pessoal.
- **Busca por significado local:** Smart Connections no Obsidian ou índice de embeddings local, sempre como camada extra.
- **Rotinas na nuvem:** `/schedule` do Claude Code para loops que não precisam da máquina ligada (só com dado que pode sair da máquina).
- **Integrações:** agenda, tickets e PRs entrando no inbox, se a política da empresa permitir.
- **Agent SDK:** se o executor crescer, reescrever em TypeScript ou Python com o Claude Agent SDK (hooks e permissões em código).
