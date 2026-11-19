# Configuração

## autonomia.json
Controla o executor autônomo (`executor.ps1`).

- `executor.ativo`: `false` por padrão. Ligue só depois de testar uma tarefa na mão com `executor.ps1 -Tarefa <nome>`.
- `max_tarefas_por_rodada`, `max_turnos`, `tentativas`: limites de custo e tempo.
- `repos`: lista de repositórios que agentes podem tocar. Repo fora da lista bloqueia a tarefa.
  - `nivel`: 0 = só plano; 1 = implementa em branch local num worktree; 2 = também faz push da branch e abre PR em rascunho (`gh`). Merge nunca é automático. A tarefa pode pedir nível menor, nunca maior.
  - `verificar`: comando que o executor roda FORA do modelo para ter evidência objetiva (testes, build). Sem ele, a tarefa vale pouco.
  - `comandos_permitidos`: prefixos de terminal que o agente pode rodar (viram `Bash(<prefixo>:*)`). Todo o resto é negado. Comece pequeno; o loop de reflexão sugere o que falta a partir das retros.

O hook `guarda.ps1` vale por cima de tudo: em modo autônomo bloqueia push, merge, reset, publish, infraestrutura e escrita fora de `propostas/`, `inbox/` e `tarefas/` do vault.
