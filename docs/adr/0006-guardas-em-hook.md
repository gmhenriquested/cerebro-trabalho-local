# ADR 0006: regras críticas em hook, não em prompt

- **Status:** aceita
- **Data:** 2026-11-19

## Contexto
Instrução em prompt é seguida quase sempre. "Quase sempre" não serve para push forçado, apagar pasta, segredo em arquivo ou agente autônomo mexendo onde não deve.

## Decisão
Um hook `PreToolUse` (`guarda.ps1`) bloqueia de forma determinística. Em sessão interativa: só o catastrófico (push forçado, apagar raiz ou home, script baixado direto no shell, DROP de banco, arquivo de segredo). Em modo autônomo (`CEREBRO_LOOP=1`): também push, merge, reset, rebase, publish, infraestrutura, elevação de privilégio e escrita no vault fora de `propostas/`, `inbox/` e `tarefas/`.

## Consequências
- Bloqueio volta para o Claude com o motivo e ele escolhe outro caminho.
- Falso positivo se resolve ajustando a regex, com ADR no vault se for específico da empresa.
