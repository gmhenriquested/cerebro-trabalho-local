---
tags: [moc]
criado: 2026-11-19
status: estavel
---

# Tarefas para agentes autônomos

Fila do executor (`executor.ps1`). Uma tarefa por arquivo, no formato de `templates/tarefa.md`. Crie com `/nova-tarefa`.

| Status | Significado | Quem muda |
|---|---|---|
| `rascunho` | escrita, ainda não liberada | você ou agentes |
| `pronta` | liberada para o executor | **só você** |
| `fazendo` | o executor está trabalhando | executor |
| `revisar` | terminou e a verificação passou; o revisor pode ter aprovado ou pedido ajuste (leia o relatório) | executor |
| `bloqueada` | falhou na verificação, o revisor bloqueou, faltou config ou a execução foi interrompida | executor |
| `feita` | você revisou e mesclou | você |
| `recusada` | você descartou (anote o motivo) | você |

O executor trabalha numa branch `agente/<tarefa>` dentro de um git worktree isolado em `%LOCALAPPDATA%\cerebro\worktrees\<tarefa>` e nunca faz merge. O relatório (o que fez, evidência, revisão independente e retro) é anexado no fim do arquivo da tarefa.

Para pedir ajuste, escreva o que mudar no fim da tarefa e volte o status para `pronta`: a branch é reaproveitada. Quando você marca `feita` ou `recusada`, o worktree é removido sozinho na próxima rodada. Agentes nunca conseguem mudar uma tarefa para `pronta` ou `feita` (a guarda bloqueia).
