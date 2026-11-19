---
name: construir
description: Fluxo disciplinado para construir software com IA (vibe coding com rede de proteção). Especificação com critérios de pronto, plano em fatias, implementação fatia por fatia com verificação real e revisão independente, commits pequenos e registro no cérebro. Use quando disserem /construir, "vamos fazer a feature X" ou ao começar algo não trivial num repositório.
---

# Construir (vibe coding com rede de proteção)

Velocidade de IA, disciplina de engenharia. Responda em português do Brasil.

## 1. Especificar (antes de qualquer código)
- Use o subagente `planejador`. Resolva com o dono as dúvidas que mudam a solução.
- Saída: objetivo, critérios de pronto verificáveis, fora do escopo, riscos, plano em fatias.
- Mostre o plano e espere o OK. Pedido trivial (uma linha, um typo) pula esta etapa.

## 2. Preparar
- Confira que está numa branch de trabalho (não na principal). Se não estiver, crie `feat/<slug>`.
- Descubra como o projeto testa e roda. Se não houver teste nenhum, proponha criar o mínimo para a área que vai mudar.
- Se o repo não tem `CLAUDE.md`, ofereça criar a partir de `templates/CLAUDE-projeto.md` do vault.

## 3. Executar fatia por fatia
Para cada fatia:
1. Teste que falha (quando fizer sentido) e depois o código mínimo que o faz passar.
2. Subagente `verificador`: build, lint e testes com evidência. Falhou: corrija a causa, nunca o teste.
3. Commit pequeno com mensagem clara.
4. Diga ao dono em uma linha o que a fatia entregou.

Se uma fatia passar de ~3 tentativas sem verificar, pare e replaneje com o dono.

## 4. Revisar
- Subagente `revisor-codigo` sobre `git diff <base>...HEAD`. Trate os bloqueantes e importantes; liste os menores.
- Confira cada critério de pronto com evidência.

## 5. Fechar
- Resumo: o que mudou, como verificar, riscos.
- No cérebro: decisão de arquitetura vira ADR em `decisoes/`; status vai na nota do projeto; aprendizado não óbvio vira memória.
- Push e PR só com pedido do dono.
