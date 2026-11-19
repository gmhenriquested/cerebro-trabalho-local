# ADR 0001: git como fonte da verdade

- **Status:** aceita
- **Data:** 2026-11-19

## Contexto
Um cérebro pode guardar notas num banco, num serviço remoto ou em arquivos. O second-brain-mcp, por exemplo, guarda no servidor e deixa o Obsidian só para leitura.

## Decisão
O vault é uma pasta de Markdown versionada no git. O Obsidian edita normalmente. Qualquer índice, busca ou integração é camada extra que lê o vault e nunca o sobrescreve.

## Consequências
- Funciona offline e sem servidor; o histórico do git é o backup e a auditoria.
- Duas máquinas exigem `pull` antes de `push`; os hooks já fazem isso e abortam em conflito.
- Busca por significado fica para depois e precisa ser reconstruível a partir dos arquivos.
