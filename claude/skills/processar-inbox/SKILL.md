---
name: processar-inbox
description: Grafo de agentes que processa o inbox do cérebro de trabalho. A triagem decide os destinos, o enriquecedor pesquisa o que falta, o curador monta as mudanças, o dono aprova e só então tudo é gravado. Use quando disserem /processar-inbox ou "processa o inbox".
---

# Processar inbox (grafo com portão humano)

```
triagem -> enriquecedor (só itens marcados) -> curador (plano) -> [você aprova] -> aplicar -> índices
```

1. **Triagem:** chame o subagente `triagem` com a lista de arquivos de `inbox/` (exceto README). Receba a tabela de destinos.
2. **Enriquecimento (em paralelo):** para cada item com `precisa_enriquecer: sim`, chame o subagente `enriquecedor` com o item e o destino. Chame vários na mesma mensagem quando forem independentes.
3. **Plano:** monte um plano único com cada item: destino, ação, conteúdo final, links. Mostre ao dono de forma compacta e pergunte com AskUserQuestion (multiSelect) o que aplicar.
4. **Aplicar:** para os aprovados, chame o subagente `curador` com o plano aprovado (ele grava, atualiza índices e apaga o item do inbox). Itens recusados ficam no inbox com uma linha `recusado em AAAA-MM-DD: <motivo>`.
5. **Tarefas:** itens que viraram tarefa vão para `tarefas/` com `status: rascunho`. Pergunte se alguma já pode ir para `pronta`.
6. Termine com o que foi para onde.
