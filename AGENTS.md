# Instruções para o agente (Claude Code ou outro)

Você foi chamado para **instalar**, **conferir** ou **aprimorar** este kit de cérebro de trabalho. Responda em português do Brasil. Leia `README.md` e `docs/arquitetura.md` antes de mexer em qualquer coisa.

## Princípios que não mudam

1. **O git é a fonte da verdade.** O vault é Markdown puro versionado. Nada de espelho que sobrescreve o vault ou banco que vira o "original".
2. **Automático aplica só o que é de baixo risco** (ADR 0008). O colhedor, o noturno e o semanal gravam sozinhos em `notas/`, `projetos/`, `pessoas/`, `referencias/`, `reunioes/`, `inbox/`, `tarefas/` (só rascunho, conferido pelo resultado da edição), `indice.md` e `memory/MEMORY.md`. Quem lê o vault em loop não tem web (ADR 0010). Memória sobre o dono, ADRs, `CLAUDE.md`, agentes, skills, `config/`, `templates/` e `evals/` são sempre proposta. A fronteira está na `guarda.ps1`.
3. **Dado da empresa não sai da máquina e do repositório privado da empresa.** Nunca envie nome de cliente, projeto interno, pessoa ou número em buscas na web, em issues públicas ou neste repositório do kit. O kit é público; o vault não.
4. **Nunca grave segredo** (token, senha, chave) em nota, memória, proposta ou log.
5. **Uma camada por vez.** Base e agentes primeiro, depois loops, grafo, autoaperfeiçoamento e por último autonomia (`docs/roadmap.md`). Cada camada tem que ser útil sozinha antes de ligar a próxima.
6. **Só Claude Code.** Nada no kit pode depender de um app de orquestração (Orca, herdr, IDE de agentes). Use hooks, subagentes, skills, `claude -p`, `git worktree` e o agendador do sistema.
7. **Regra crítica vai em hook** (`guarda.ps1`), não só em prompt. Merge é sempre humano.
8. **Sem ritual manual.** O dono não vai lembrar de rodar nada. Toda melhoria deve funcionar sozinha (hook, loop) ou caber na revisão de um clique.

## Instalar

1. Confira os pré-requisitos: `git --version`, `claude --version`. O Obsidian é opcional para o Claude, mas o dono vai querer.
2. Rode `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\instalar.ps1` (parâmetros: `-Vault <caminho>`, `-SemAgendar`).
3. Se o `settings.json` já tinha hooks, o instalador **não mescla sozinho**: ele grava `%USERPROFILE%\.claude\hooks\cerebro\settings.hooks.json`. Mescle você mesmo, sem apagar os hooks existentes, e mostre o diff ao dono.
4. Se a política da empresa bloquear o Agendador de Tarefas ou o `ExecutionPolicy`, avise o dono e registre em `docs/adr/` do vault (não no kit) como ficou.
5. Pergunte ao dono se quer um repositório remoto **privado** para o vault (backup ou várias máquinas). Se sim, `git remote add origin <url>` e `git push -u origin main` dentro do vault. Sem remoto, o sync só faz commit local.

## Conferir

- `scripts\windows\lint.ps1` roda sem erro e escreve o relatório.
- Abra uma sessão nova do Claude Code: o contexto do cérebro aparece no início (hook SessionStart).
- Converse por uns 8 turnos: o colhedor dispara em segundo plano (veja `cerebro.log` e `propostas/AAAA-MM-DD-colhedor-*.md`); o sync faz commit e push. Log em `%USERPROFILE%\.claude\state\cerebro\cerebro.log`.
- Com propostas pendentes, abra uma sessão nova e peça qualquer coisa: depois dessa primeira tarefa o Claude deve oferecer a revisão de um clique.
- Rode cada loop na mão uma vez (`loop-reflexao.ps1`, `loop-noturno.ps1`, `loop-semanal.ps1`) e confira o arquivo em `propostas/`.
- Guarda: rode `scripts\windows\testar-guarda.ps1`; todos os casos têm que dar `ok`. Depois peça numa sessão para rodar `git push --force` num repo qualquer; tem que ser bloqueado com a mensagem da guarda.
- Evals: `evals.ps1` roda o caso de exemplo, grava em `evals/historico.csv` (com modelo) e, se um modelo mais barato passar, cria uma proposta do tipo `modelo`. Rodar de novo sem mudar nada deve usar só o cache.
- Métricas: depois de qualquer loop, `metricas/loops.csv` tem uma linha com papel, modelo, custo e turnos.
- Pontos a observar num Windows real: latência da guarda a cada ferramenta (antivírus corporativo), agendamento sem admin, ExecutionPolicy ou modo restrito do PowerShell imposto pela empresa, e se `--setting-sources user` ainda deixa o `--agent` dos evals achar o agente da pasta temporária.
- Executor: com `config/cerebro.json` apontando para um repo de teste em nível 0, rode `executor.ps1 -Tarefa <nome>` e leia o relatório no fim da tarefa. Os scripts nunca foram executados num Windows real antes da sua instalação: espere ajustes e corrija aqui no kit.

## Aprimorar

O dono vai pedir para você adaptar a arquitetura ao trabalho dele. Bom ponto de partida:

- `docs/roadmap.md` tem as melhorias já pensadas, em ordem.
- Mudança de comportamento do kit (algo que valeria para qualquer pessoa): edite aqui no kit e registre um ADR em `docs/adr/`.
- Mudança específica da empresa ou do dono (pastas, agentes do domínio, nomes): faça **no vault**, nunca no kit público. Os hooks de `scripts/git-hooks` (ligados com `core.hooksPath`) bloqueiam commit no kit com termo de `config/termos-internos.txt`; não pule com `--no-verify`.
- Ao criar agente novo, siga o formato de `claude/agents/` (frontmatter `name`, `description`, `tools`, `model`), dê o mínimo de ferramentas e escreva quando usar na `description`.
- Ao criar loop novo, siga o padrão dos existentes: `Test-LoopAtivo`, trava contra execução dupla, `Invoke-Claude` da `lib.ps1` com `-Papel` (modelo e métricas) e `-Raizes` (onde pode escrever) (que liga `CEREBRO_LOOP=1` para silenciar os hooks de ritual), ferramentas mínimas, `-Escrita` só se for aplicar baixo risco, `Save-Resultado` para a saída (aplicado vai para o log do dia, pendente para `propostas/`), log em `cerebro.log`.
- Scripts `.ps1` precisam funcionar no Windows PowerShell 5.1 e ser salvos em **UTF-8 com BOM** (sem BOM, acentos quebram no 5.1).
- Textos para pessoas: português claro, sem jargão, sem travessão.
