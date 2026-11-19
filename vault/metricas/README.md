# Métricas

Gravadas pelos scripts, sem custo extra (avaliação passiva). O loop semanal resume a tendência.

| Arquivo | O que tem |
|---|---|
| `loops.csv` | cada chamada de `claude -p`: papel, modelo, se deu certo, custo em US$, turnos, segundos |
| `executor.csv` | cada tarefa autônoma: modelo final, verificação, tentativas, veredito do revisor |

As notas dos evals ficam em `evals/historico.csv`. As decisões das propostas, em `propostas/metricas.csv`.
