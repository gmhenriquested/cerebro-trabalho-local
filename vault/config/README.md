# Configuração

## cerebro.json
Configuração do cérebro.

### colhedor
Lê a conversa em segundo plano e guarda no vault o que importa, sem interromper você.
- `ativo`: liga/desliga.
- `a_cada_turnos`: roda a cada N respostas do Claude na mesma sessão (padrão 8).
- `minutos_minimos`: também roda se passou esse tempo desde a última colheita e houve pelo menos 3 turnos (pega sessões curtas fechadas de repente).
- Sempre roda antes de compactar o contexto (`PreCompact`) e no fim da sessão (`SessionEnd`).

### revisao_na_sessao
Quando há propostas pendentes, o Claude oferece aprovar em uma pergunta de múltipla escolha, numa pausa natural, no máximo `max_por_dia` vezes por dia.

### loops
Liga ou desliga cada loop agendado (`reflexao`, `noturno`, `semanal`) sem mexer no Agendador de Tarefas.

### modelos
Qual modelo cada papel usa (ADR 0009).
- `padrao`: modelo de qualquer papel não listado.
- `escada`: do mais barato para o mais forte; usada pelos evals e pela escalada do executor. Pode incluir outros apelidos aceitos pelo `claude --model`.
- `papeis`: loops e etapas (`colhedor`, `noturno`, `pesquisa_web` para a pesquisa isolada do noturno, `semanal`, `reflexao`, `juiz`, `executor`, `executor_escalar` na nova tentativa, `revisor_executor`).
- `agentes`: subagentes; o SessionStart grava o modelo no frontmatter de cada um sozinho quando este arquivo muda.

### evals
- `nota_minima`: nota (0 a 10) para um modelo ser considerado bom o bastante.
- `max_chamadas`: teto por rodada (cada caso = 1 execução + 1 juiz).
- `validade_dias`: quanto tempo um resultado fica em cache.

### termos-internos.txt
Um termo por linha (clientes, projetos, sistemas, pessoas). Em modo automático, a guarda bloqueia buscas na web que contenham algum deles.

### executor
Controla o executor autônomo (`executor.ps1`).

- `executor.ativo`: `false` por padrão. Ligue só depois de testar uma tarefa na mão com `executor.ps1 -Tarefa <nome>`.
- `max_tarefas_por_rodada`, `max_turnos`, `tentativas`: limites de custo e tempo.
- `repos`: lista de repositórios que agentes podem tocar. Repo fora da lista bloqueia a tarefa.
  - `nivel`: 0 = só plano; 1 = implementa em branch local num worktree; 2 = também faz push da branch e abre PR em rascunho (`gh`). Merge nunca é automático. A tarefa pode pedir nível menor, nunca maior.
  - `verificar`: comando que o executor roda FORA do modelo para ter evidência objetiva (testes, build). Sem ele, a tarefa vale pouco.
  - `comandos_permitidos`: prefixos de terminal que o agente pode rodar (viram `Bash(<prefixo>:*)`, ou `PowerShell(...)` sem Git Bash). Os outros comandos são negados, **mas** comandos como `npm test` rodam scripts do próprio repositório, que o agente pode editar: trate o nível 1 como "executa código com o seu usuário" (ver ADR 0005). Comece pequeno; o loop de reflexão sugere o que falta a partir das retros.

O hook `guarda.ps1` vale por cima de tudo. Em modo autônomo bloqueia push, merge, reset, publish e infraestrutura. No vault, o executor só escreve em `propostas/`, `inbox/` e `tarefas/`. O colhedor, o noturno e o semanal (modo de escrita automática) também podem escrever em `notas/`, `projetos/`, `pessoas/`, `referencias/`, `reunioes/`, `indice.md` e `memory/MEMORY.md`. Memórias, `decisoes/`, `CLAUDE.md`, `config/`, `templates/` e `evals/` só mudam com você presente. Em `tarefas/`, agente sem você só cria ou edita rascunho. No repositório, o executor não mexe em CI, hooks do git, `package.json` e parecidos (ADR 0010).
