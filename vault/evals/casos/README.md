# Casos de eval

Cada correção importante do dono vira um caso aqui, para o erro não voltar quando um agente ou prompt mudar.

Formato (`evals/casos/<alvo>-<assunto>.md`):

```markdown
---
alvo: triagem        # nome do agente em ~/.claude/agents, ou "geral"
criado: AAAA-MM-DD
origem: correção do dono em AAAA-MM-DD
---

## Entrada
O pedido, exatamente como o agente receberia.

## Critérios
- O que a resposta TEM que fazer.
- O que ela NÃO pode fazer (o erro que aconteceu).
```

Rodar: `~/.claude/hooks/cerebro/evals.ps1` (todos) ou `-Filtro triagem`. Resultado em `evals/resultados/` e histórico em `evals/historico.csv` (com hash da versão do agente). O loop semanal mostra a tendência.
