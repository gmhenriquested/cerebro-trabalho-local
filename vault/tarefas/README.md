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
| `revisar` | terminou, verificação ok; esperando sua revisão | executor |
| `bloqueada` | falhou na verificação, o revisor bloqueou ou faltou config | executor |
| `feita` | você revisou e mesclou | você |
| `recusada` | você descartou (anote o motivo) | você |

O executor trabalha numa branch `agente/<tarefa>` dentro de um git worktree isolado e nunca faz merge. O relatório (o que fez, evidência, revisão independente e retro) é anexado no fim do arquivo da tarefa. Depois de revisar: `git worktree remove <caminho>`.
