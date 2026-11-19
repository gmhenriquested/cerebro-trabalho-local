# ADR 0004: Windows PowerShell 5.1 sem dependências extras

- **Status:** aceita
- **Data:** 2026-11-19

## Contexto
Máquinas corporativas costumam ter instalação restrita. Python ou Node podem não estar disponíveis.

## Decisão
Todos os scripts são Windows PowerShell 5.1, que já vem no Windows. Agendamento via Agendador de Tarefas. Os arquivos `.ps1` são salvos em UTF-8 com BOM.

## Consequências
- O digest das conversas e o lint são escritos em PowerShell, mais verboso que Python, porém sem instalar nada.
- Se o `ExecutionPolicy` ou o Agendador forem bloqueados, os loops podem rodar na mão.
