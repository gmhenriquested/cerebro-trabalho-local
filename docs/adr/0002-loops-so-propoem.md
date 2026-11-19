# ADR 0002: loops automáticos só propõem

- **Status:** aceita
- **Data:** 2026-11-19

## Contexto
Um sistema que reescreve a própria memória sem supervisão acumula erro e ruído, e ninguém percebe até ficar ruim.

## Decisão
Tudo que roda sem o dono presente (loops agendados, agentes de leitura) escreve só em `propostas/`. A promoção para `notas/`, `decisoes/`, `projetos/` ou `memory/` acontece numa sessão com o dono, via `/revisar-propostas` ou `/processar-inbox`.

## Consequências
- O dono precisa revisar com frequência; propostas velhas aparecem no lint semanal.
- Recusas viram sinal: com motivo, viram memória de feedback.
- Os loops rodam com ferramentas só de leitura e hooks desligados.
