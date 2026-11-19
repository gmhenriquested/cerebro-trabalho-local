# Cérebro de Trabalho (kit)

Kit para montar um **segundo cérebro de trabalho** operado pelo **Claude Code**, com agentes, loops de aprendizado e execução autônoma de tarefas. Feito para Windows.

O vault é uma pasta de Markdown versionada no git, que você abre no Obsidian. O Claude lê o vault no começo de cada sessão e salva nele o que aprende. Loops agendados **propõem** melhorias, e um executor autônomo faz tarefas de código em branches isoladas. Quem aprova é você.

Tudo é Claude Code puro: `CLAUDE.md`, hooks, subagentes, skills, `claude -p` e `git worktree`. Não depende de nenhum app de orquestração.

> Este repositório tem só a estrutura e os scripts. O seu vault de trabalho vira um repositório **separado e privado**.

## As 5 camadas

| Camada | O que é | Onde está |
|---|---|---|
| 1. Agentes | 8 subagentes especializados, cada um com papel e ferramentas mínimas | `claude/agents/` |
| 2. Loops | Reflexão, noturno e semanal rodando sozinhos no Agendador de Tarefas | `scripts/windows/loop-*.ps1` |
| 3. Grafo | Agentes passando trabalho entre si com portão humano | `/processar-inbox`, `/construir`, executor |
| 4. Autoaperfeiçoamento | Suas correções, as retros dos agentes e suas recusas viram propostas; correções viram evals | `loop-reflexao.ps1`, `evals.ps1`, `/revisar-propostas` |
| 5. Execução autônoma | Fila de tarefas, executor em worktree, verificação real, revisor independente, níveis de autonomia, guardas em hook | `tarefas/`, `executor.ps1`, `guarda.ps1` |

A regra que segura tudo: **o automático propõe; quem promove e mescla é você.**

Detalhes em [docs/arquitetura.md](docs/arquitetura.md). As decisões estão em [docs/adr/](docs/adr/). A ordem de implantação está em [docs/roadmap.md](docs/roadmap.md).

## Instalar (Windows)

Pré-requisitos: Git, Claude Code e Obsidian. Python e Node não são necessários. Para PR automático (nível 2), instale também o `gh`.

```powershell
git clone https://github.com/gmhenriquested/cerebro-trabalho-kit
cd cerebro-trabalho-kit
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\instalar.ps1
```

O instalador cria o vault em `%USERPROFILE%\cerebro-trabalho` (ou no caminho de `-Vault`) sem sobrescrever nada, copia os agentes e skills para `%USERPROFILE%\.claude\`, liga os hooks, acrescenta as regras ao `CLAUDE.md` global e agenda os loops (`-SemAgendar` pula essa parte). O executor autônomo fica **desligado** até você configurar.

Ou peça ao Claude: *"Clone github.com/gmhenriquested/cerebro-trabalho-kit, instale seguindo o AGENTS.md e depois me ajude a adaptar a arquitetura."*

## Uso no dia a dia

| Quero... | Faço |
|---|---|
| Guardar uma ideia ou anotação | `/capturar <texto>` |
| Organizar o que está no inbox | `/processar-inbox` |
| Transformar uma reunião em ata, decisões e tarefas | "usa o agente ata nisso" |
| Construir uma feature com IA sem perder o controle | `/construir` |
| Deixar uma tarefa para um agente fazer sozinho | `/nova-tarefa` |
| Pedir pesquisa para uma nota | `enriquecer: true` no frontmatter |
| Aprovar o que os loops sugeriram | `/revisar-propostas` |
| Arrumar o vault | "organiza o cérebro" (agente `curador`) |

## Agentes

| Agente | Papel |
|---|---|
| `curador` | arruma o vault: índices, links, duplicatas, memória velha |
| `triagem` | decide para onde vai cada item do inbox |
| `enriquecedor` | pesquisa e propõe conteúdo para uma nota |
| `ata` | reunião -> ata, ADRs e tarefas |
| `pesquisador` | dúvida técnica com fonte |
| `planejador` | pedido vago -> especificação, critérios de pronto e fatias |
| `revisor-codigo` | revisão cética, inclusive dos erros típicos de código de IA |
| `verificador` | roda build e testes e devolve evidência |

## Loops agendados

| Loop | Quando | O que faz |
|---|---|---|
| `loop-reflexao.ps1` | dias úteis, 18h | lê suas falas, as retros dos agentes e suas recusas; propõe mudanças em memória, agentes, prompts e evals |
| `loop-noturno.ps1` | dias úteis, 19h | sugere destino para o inbox e pesquisa notas marcadas |
| `executor.ps1` | dias úteis, 20h | executa tarefas `pronta` (desligado por padrão) |
| `loop-semanal.ps1` | sexta, 17h | lint do vault, métricas, resumo da semana e correções |

Saída sempre em `propostas/AAAA-MM-DD-<loop>.md`. Log em `%USERPROFILE%\.claude\state\cerebro\cerebro.log`.

## Créditos e inspiração

- Camadas agentes -> loops -> grafos -> autoaperfeiçoamento: setups de Claude Code que circulam entre engenheiros.
- Fila, reconciliação e ADRs: [YudiG12/second-brain-mcp](https://github.com/YudiG12/second-brain-mcp). Aqui a fonte da verdade continua sendo o git, com o Obsidian editável.

Licença MIT.
