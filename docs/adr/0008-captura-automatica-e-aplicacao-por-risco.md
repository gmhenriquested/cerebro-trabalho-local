# ADR 0008: captura automática e aplicação por nível de risco

- **Status:** aceita (substitui em parte a ADR 0002)
- **Data:** 2026-11-19

## Contexto
Na prática, quem usa o Claude Code manda o prompt e segue em frente. Rituais manuais (lembrete no fim do turno, `/capturar`, `/processar-inbox`, `/revisar-propostas`) não viram hábito, então o cérebro para de crescer e as propostas se acumulam. O lembrete no hook Stop ainda interrompia o fluxo.

## Decisão
1. **Colhedor em segundo plano** no lugar do lembrete. Os hooks Stop (a cada N turnos ou M minutos), PreCompact e SessionEnd disparam um worker escondido que lê só o trecho novo da conversa (`transcript_path`) e guarda o que é durável. A sessão nunca é interrompida.
2. **Aplicação por nível de risco.** O colhedor, o noturno e o semanal rodam com `CEREBRO_ESCRITA=auto` e aplicam sozinhos o que é de baixo risco: status de projeto, anexos em notas, pessoas, referências, inbox, tarefas em rascunho, consertos de link e de índice. Memória sobre o dono, ADRs, `CLAUDE.md`, agentes, skills, `config/`, `templates/`, `evals/` e apagar coisas continuam como proposta. A fronteira é garantida pela `guarda.ps1`, não pelo prompt.
3. **Revisão de um clique.** O SessionStart lista as propostas pendentes e pede ao Claude que, depois da primeira tarefa da sessão, ofereça aprovar numa única pergunta de múltipla escolha, no máximo uma vez por dia (configurável).
4. **Auditoria.** Tudo o que é aplicado sozinho vai para o relatório `## Aplicado automaticamente` e para commits separados. O semanal relê essas mudanças e corrige o que estiver errado.

## Consequências
- O cérebro cresce sem esforço; o dono só responde uma pergunta por dia, no máximo.
- Custo extra: algumas chamadas de `claude -p` por sessão. Ajustável em `config/cerebro.json`.
- Risco de gravar algo errado ou redundante. Mitigação: só áreas de baixo risco, git para desfazer, revisão semanal do que foi aplicado, prompt conservador ("a maioria dos trechos não tem nada").
