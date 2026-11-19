---
name: nova-tarefa
description: Escreve uma tarefa para o executor autônomo do cérebro de trabalho (tarefas/ no vault), com objetivo, critérios de pronto verificáveis, escopo e nível de autonomia, e só a libera (status pronta) com o OK do dono. Use quando disserem /nova-tarefa, "deixa isso pro agente fazer" ou "coloca na fila do executor".
---

# Nova tarefa para o executor

Uma tarefa autônoma só dá certo se o critério de pronto for verificável por máquina. Responda em português do Brasil.

1. Entenda o pedido. Leia `config/cerebro.json` do vault para saber quais repos o executor pode usar, com que nível e qual comando de verificação.
2. Se o repo não estiver lá, diga ao dono e pergunte se quer adicionar (caminho, branch base, nível, comando de verificação, comandos permitidos). Nível 0 = só plano; 1 = implementa em branch local; 2 = também faz push da branch e abre PR em rascunho. Merge nunca é automático.
3. Use o subagente `planejador` para escrever a especificação no formato de `templates/tarefa.md`.
4. Revise os critérios de pronto com o dono: cada um precisa ser checável por comando, teste ou comportamento observável. "Ficar bom" não é critério.
5. Grave em `tarefas/AAAA-MM-DD-<slug>.md` com `status: rascunho`. Pergunte se pode mudar para `pronta`. O executor roda às 20h nos dias úteis, ou na hora com `~/.claude/hooks/cerebro/executor.ps1 -Tarefa <slug>`.
6. Tarefa grande: quebre em várias, cada uma entregável sozinha.
