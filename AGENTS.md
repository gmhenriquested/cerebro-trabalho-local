# Instruções para o agente (Claude Code ou outro)

Você foi chamado para **instalar**, **conferir** ou **aprimorar** este kit de cérebro de trabalho. Responda em português do Brasil. Leia `README.md` e `docs/arquitetura.md` antes de mexer em qualquer coisa.

## Princípios que não mudam

1. **O git é a fonte da verdade.** O vault é Markdown puro versionado. Nada de espelho que sobrescreve o vault ou banco que vira o "original".
2. **Loop automático só propõe.** Tudo que roda sem ninguém olhando escreve em `propostas/` ou `inbox/`. Quem promove para `notas/`, `decisoes/`, `projetos/` ou `memory/` é uma sessão com o dono presente.
3. **Dado da empresa não sai da máquina e do repositório privado da empresa.** Nunca envie nome de cliente, projeto interno, pessoa ou número em buscas na web, em issues públicas ou neste repositório do kit. O kit é público; o vault não.
4. **Nunca grave segredo** (token, senha, chave) em nota, memória, proposta ou log.
5. **Uma camada por vez.** Base e agentes primeiro, depois loops, grafo, autoaperfeiçoamento e por último autonomia (`docs/roadmap.md`). Cada camada tem que ser útil sozinha antes de ligar a próxima.
6. **Só Claude Code.** Nada no kit pode depender de um app de orquestração (Orca, herdr, IDE de agentes). Use hooks, subagentes, skills, `claude -p`, `git worktree` e o agendador do sistema.
7. **Regra crítica vai em hook** (`guarda.ps1`), não só em prompt. Merge é sempre humano.

## Instalar

1. Confira os pré-requisitos: `git --version`, `claude --version`. O Obsidian é opcional para o Claude, mas o dono vai querer.
2. Rode `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\instalar.ps1` (parâmetros: `-Vault <caminho>`, `-SemAgendar`).
3. Se o `settings.json` já tinha hooks, o instalador **não mescla sozinho**: ele grava `%USERPROFILE%\.claude\hooks\cerebro\settings.hooks.json`. Mescle você mesmo, sem apagar os hooks existentes, e mostre o diff ao dono.
4. Se a política da empresa bloquear o Agendador de Tarefas ou o `ExecutionPolicy`, avise o dono e registre em `docs/adr/` do vault (não no kit) como ficou.
5. Peça ao dono a URL do repositório privado do vault e rode `git remote add origin <url>` e `git push -u origin main` dentro do vault.

## Conferir

- `scripts\windows\lint.ps1` roda sem erro e escreve o relatório.
- Abra uma sessão nova do Claude Code: o contexto do cérebro aparece no início (hook SessionStart).
- Termine um turno: o hook Stop lembra de salvar memória uma vez por sessão; o sync faz commit e push em segundo plano. Log em `%USERPROFILE%\.claude\state\cerebro\cerebro.log`.
- Rode cada loop na mão uma vez (`loop-reflexao.ps1`, `loop-noturno.ps1`, `loop-semanal.ps1`) e confira o arquivo em `propostas/`.
- Guarda: peça para rodar `git push --force` num repo qualquer; tem que ser bloqueado com a mensagem da guarda.
- Evals: `evals.ps1` roda o caso de exemplo e grava em `evals/historico.csv`.
- Executor: com `autonomia.json` apontando para um repo de teste em nível 0, rode `executor.ps1 -Tarefa <nome>` e leia o relatório no fim da tarefa. Os scripts nunca foram executados num Windows real antes da sua instalação: espere ajustes e corrija aqui no kit.

## Aprimorar

O dono vai pedir para você adaptar a arquitetura ao trabalho dele. Bom ponto de partida:

- `docs/roadmap.md` tem as melhorias já pensadas, em ordem.
- Mudança de comportamento do kit (algo que valeria para qualquer pessoa): edite aqui no kit e registre um ADR em `docs/adr/`.
- Mudança específica da empresa ou do dono (pastas, agentes do domínio, nomes): faça **no vault**, nunca no kit público.
- Ao criar agente novo, siga o formato de `claude/agents/` (frontmatter `name`, `description`, `tools`, `model`), dê o mínimo de ferramentas e escreva quando usar na `description`.
- Ao criar loop novo, siga o padrão dos existentes: trava contra execução dupla, `claude -p` com `--settings` sem hooks, ferramentas só de leitura, saída em `propostas/`, log em `cerebro.log`.
- Scripts `.ps1` precisam funcionar no Windows PowerShell 5.1 e ser salvos em **UTF-8 com BOM** (sem BOM, acentos quebram no 5.1).
- Textos para pessoas: português claro, sem jargão, sem travessão.
