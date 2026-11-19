# ADR 0009: modelo por papel, escolhido por medida e não por chute

- **Status:** aceita
- **Data:** 2026-11-19

## Contexto
Rodar tudo no modelo mais forte é caro e lento. Isso pesa mais no colhedor, que roda várias vezes por sessão e consome a mesma cota de uso do dono. Rodar tudo no modelo mais barato perde qualidade onde errar custa caro: revisão, planejamento e reflexão. Testar todos os modelos o tempo todo também é desperdício.

## Decisão
1. **Roteamento:** `config/cerebro.json > modelos` define o modelo de cada papel (loops e etapas do executor) e de cada subagente. O `Invoke-Claude` passa `--model`, e o SessionStart grava o `model:` no frontmatter dos agentes quando a config muda.
2. **Avaliação passiva, sem custo extra:** toda chamada grava papel, modelo, sucesso, custo e turnos em `metricas/loops.csv`; o executor grava modelo final, verificação, tentativas e veredito em `metricas/executor.csv`. O semanal lê a tendência e propõe subir ou descer um modelo.
3. **Avaliação ativa, barata:** `evals.ps1` usa cache por (caso, versão do agente, modelo), roda só com motivo (agente mudou ou cache venceu), em cascata (testa o atual; se passa, tenta os mais baratos do mais barato para cima e para no primeiro que passa; se falha, sobe) e com teto de chamadas.
4. **Escalada no executor:** a primeira tentativa usa o modelo de `executor`; a correção depois de uma verificação que falhou usa o de `executor_escalar`.
5. Toda troca de modelo é proposta (tipo `modelo`) e passa pela revisão de um clique.

## Consequências
- O custo fica visível no resumo semanal.
- O padrão inicial é um palpite razoável (barato para tarefas mecânicas, forte para julgamento). As medidas corrigem com o tempo.
- Juiz LLM erra: os critérios dos casos precisam ser concretos.
