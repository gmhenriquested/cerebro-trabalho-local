# ADR 0006: regras críticas em hook, não em prompt

- **Status:** aceita
- **Data:** 2026-11-19

## Contexto
Instrução em prompt é seguida quase sempre. "Quase sempre" não serve para push forçado, apagar pasta, segredo em arquivo ou agente autônomo mexendo onde não deve.

## Decisão
Um hook `PreToolUse` (`guarda.ps1`) bloqueia de forma determinística. Em sessão interativa: só o catastrófico (push forçado, apagar raiz ou home, script baixado direto no shell, DROP de banco, arquivo de segredo). Em modo autônomo (`CEREBRO_LOOP=1`): também push, merge, reset, rebase, publish, infraestrutura, elevação de privilégio e escrita no vault fora de `propostas/`, `inbox/` e `tarefas/`.

## Atualização (revisão de 2026-11-19)
- Em modo autônomo a guarda **falha fechado**: se não carregar, não entender a entrada ou a ferramenta vier sem nome, ela nega.
- Escrita só dentro das raízes do papel (`CEREBRO_RAIZES`), com o caminho normalizado (`GetFullPath`; `..` e `\\?\` não contornam).
- Bloqueia mudar tarefa para `pronta`/`feita`, `Write` que reescreve uma nota inteira, `Read` de credenciais e buscas na web com termos de `config/termos-internos.txt`.
- Duas camadas independentes: a guarda (hook) e as regras `deny` de `loop-settings.json`, passadas com `--settings` em toda chamada dos loops.

## Atualização (ADR 0010)
- Tarefas: a guarda simula o Write, Edit ou MultiEdit e decide pelo frontmatter resultante; só rascunho passa, e tarefa que já não é rascunho não é tocada.
- Em modo autônomo, nega escrita em arquivos que fazem código rodar sozinho (`.github`, `.husky`, `.vscode`, `package.json`...).
- Na sessão interativa a guarda **falha aberto** de propósito (se não carregar, deixa passar), para um erro no script não travar seu trabalho. Rode `testar-guarda.ps1` depois de mexer nela.

## Consequências
- Bloqueio volta para o Claude com o motivo e ele escolhe outro caminho.
- Falso positivo se resolve ajustando a regex, com ADR no vault se for específico da empresa.
