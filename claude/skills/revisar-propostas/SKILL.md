---
name: revisar-propostas
description: Revisa com o dono as propostas geradas pelos loops do cérebro de trabalho (arquivos em propostas/ do vault) e aplica só as aprovadas. Use quando disserem /revisar-propostas, "revisa as propostas" ou quando o início da sessão avisar que há propostas pendentes.
---

# Revisar propostas

Os loops (colhedor, reflexão, noturno, semanal, evals, executor) já aplicam sozinhos o que é de baixo risco (registrado em `propostas/AAAA-MM-DD-auto.md`). O que está aqui como `pendente` é o que muda comportamento ou é sensível e ainda não foi aplicado. Responda em português do Brasil.

1. Liste os arquivos de `propostas/` com `**Status:** pendente`. Se não houver, diga e pare.
2. Para cada proposta, leia o arquivo alvo atual e confira se ainda faz sentido (pode ter sido resolvida noutra sessão; nesse caso marque `obsoleta`).
3. Mostre um resumo de todas de uma vez (título, tipo, arquivo, por quê em uma linha, confiança) e pergunte com AskUserQuestion (multiSelect) quais aplicar. Alertas são só avisos, em destaque.
4. **Mudança em agente ou prompt de loop:** se existir caso em `evals/casos/` para aquele alvo, rode `~/.claude/hooks/cerebro/evals.ps1 -Filtro <alvo>` antes e depois e mostre as notas. Nota caiu: pergunte se mantém.
4b. **Proposta do tipo `modelo`:** edite só a seção `modelos` de `config/cerebro.json` do vault. O SessionStart grava o modelo no agente sozinho; para valer já nesta sessão, rode `~/.claude/hooks/cerebro/aplicar-modelos.ps1`. Se a proposta veio das métricas passivas (e não dos evals) e o alvo tem casos em `evals/casos/`, rode `evals.ps1 -Filtro <alvo> -SemCascata` com o modelo novo antes de aplicar.
5. Aplique as aprovadas seguindo o `CLAUDE.md` do vault (memória no índice, nada duplicado, datas absolutas, nunca segredo).
6. Marque o status: `aplicada (AAAA-MM-DD)`, `recusada (AAAA-MM-DD): <motivo>`, `ajustada (AAAA-MM-DD): <o que mudou>` ou `obsoleta (AAAA-MM-DD)`. Peça o motivo de cada recusa em uma linha: o loop de reflexão lê esses motivos para não insistir.
7. Acrescente uma linha por proposta em `propostas/metricas.csv` (crie com o cabeçalho `data,arquivo,proposta,tipo,resultado` se não existir).
8. Termine com a lista do que mudou e onde.
