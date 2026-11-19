# ADR 0007: correção vira caso de eval

- **Status:** aceita
- **Data:** 2026-11-19

## Contexto
O loop de reflexão muda agentes e prompts a partir das correções. Sem medida, uma mudança pode consertar um caso e quebrar outro sem ninguém ver.

## Decisão
Erro que pode voltar vira caso em `evals/casos/` (entrada + critérios). `evals.ps1` roda o agente alvo, um juiz dá nota 0-10 pelos critérios, e o resultado vai para `evals/historico.csv` com o hash da versão do agente. `/revisar-propostas` roda os evals antes e depois de mudar agente ou prompt.

## Consequências
- Custa algumas chamadas por mudança; vale porque mudanças em agente são raras e de alto impacto.
- LLM como juiz erra; os critérios precisam ser concretos e checáveis.
