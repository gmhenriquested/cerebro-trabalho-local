# Cérebro de Trabalho Local

Arquitetura pronta para quem quer um **segundo cérebro de trabalho** operado pelo **Claude Code**, guardado no próprio computador.

- **Local:** as notas são uma pasta de Markdown no seu disco, versionada com git e aberta no Obsidian. Nenhum servidor, banco ou serviço na nuvem. O repositório remoto é opcional, e você decide onde fica.
- **Sem ritual:** você só trabalha. Um colhedor lê a conversa em segundo plano e guarda o que importa, os loops arrumam o vault e você aprova o resto com um clique por dia.
- **Agentes de verdade:** 8 subagentes, loops de aprendizado, evals e um executor que faz tarefas de código sozinho numa branch isolada, com testes, revisão independente e guardas.
- **Só Claude Code:** `CLAUDE.md`, hooks, subagentes, skills, `claude -p` e `git worktree`. Não depende de nenhum app de orquestração.
- **Windows** (PowerShell 5.1, que já vem instalado). Não precisa de Python nem Node.

## Como funciona no dia a dia

| Momento | O que acontece sozinho | Você faz |
|---|---|---|
| Começo da sessão | O Claude recebe o índice do cérebro e a sua memória | nada |
| Durante a sessão | A cada ~8 turnos, antes de compactar o contexto e no fim, o **colhedor** grava status de projeto, aprendizados, pessoas e tarefas | nada |
| Fim de cada turno | Commit (e push, se tiver remoto) do vault | nada |
| 18h | A **reflexão** lê suas correções e as retros dos agentes e propõe melhorias no próprio sistema | nada |
| 19h | O **noturno** arquiva o inbox e pesquisa as notas marcadas | nada |
| 20h | O **executor** faz as tarefas liberadas (desligado por padrão) | revisar e mesclar a branch |
| Sexta 17h | O **semanal** conserta o vault, confere o que foi aplicado sozinho e escreve o resumo | ler, se quiser |
| Depois da 1ª tarefa do dia | O Claude oferece as propostas pendentes numa pergunta de múltipla escolha | um clique |

**O que o automático aplica sozinho:** só coisas de baixo risco, como status de projeto, notas, pessoas, referências, inbox, tarefas em rascunho e índices. **O que vira proposta:** memória sobre você, decisões (ADR), agentes, skills, regras e configuração. Quem garante essa fronteira é um hook, não o prompt. Tudo fica no git e pode ser desfeito.

## As 5 camadas

| Camada | O que é | Onde está |
|---|---|---|
| 1. Agentes | curador, triagem, enriquecedor, ata, pesquisador, planejador, revisor-codigo, verificador | `claude/agents/` |
| 2. Loops | colhedor, reflexão, noturno, semanal | `scripts/windows/` |
| 3. Grafo | Agentes passando trabalho entre si: `/processar-inbox`, `/construir`, executor | `claude/skills/` |
| 4. Autoaperfeiçoamento | Correções, retros e recusas viram propostas; correções viram evals com um Claude como juiz | `loop-reflexao.ps1`, `evals.ps1` |
| 5. Execução autônoma | Fila de tarefas, executor em git worktree, verificação real, revisor independente, níveis de autonomia, merge sempre humano | `tarefas/`, `executor.ps1`, `guarda.ps1` |

Detalhes em [docs/arquitetura.md](docs/arquitetura.md). As decisões estão em [docs/adr/](docs/adr/). A ordem de implantação está em [docs/roadmap.md](docs/roadmap.md).

## Instalar

Pré-requisitos: Git, Claude Code e Obsidian. Para PR automático (nível 2 do executor), também o `gh`.

```powershell
git clone https://github.com/gmhenriquested/cerebro-trabalho-local
cd cerebro-trabalho-local
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\instalar.ps1
```

O instalador:
- cria o vault em `%USERPROFILE%\cerebro-trabalho` (ou no caminho de `-Vault`) sem sobrescrever nada;
- copia agentes e skills para `%USERPROFILE%\.claude\`;
- liga os hooks e acrescenta as regras ao `CLAUDE.md` global;
- agenda os loops (`-SemAgendar` pula essa parte).

Depois:
1. Abra a pasta do vault no Obsidian ("Open folder as vault").
2. (Opcional) Para backup ou para usar em mais de uma máquina, crie um repositório **privado** e rode `git -C <vault> remote add origin <url>`. Sem remoto, tudo fica só no seu disco.

Ou peça ao Claude: *"Clone github.com/gmhenriquested/cerebro-trabalho-local, instale seguindo o AGENTS.md e depois me ajude a adaptar a arquitetura ao meu trabalho."*

> Este repositório tem só a estrutura e os scripts. O seu vault é outra pasta, e as suas notas nunca voltam para cá.

## Comandos (opcionais)

Nada aqui é obrigatório, porque o automático cobre o dia a dia. Use quando quiser:

| Quero... | Faço |
|---|---|
| Guardar algo agora | `/capturar <texto>` |
| Organizar o inbox na hora | `/processar-inbox` |
| Ata de reunião, com decisões e tarefas | "usa o agente ata nisso" |
| Construir uma feature com IA sem perder o controle | `/construir` |
| Deixar uma tarefa para um agente fazer sozinho | `/nova-tarefa` |
| Pesquisa para uma nota | `enriquecer: true` no frontmatter |
| Ver todas as propostas de uma vez | `/revisar-propostas` |

## Configurar

Tudo em `<vault>\config\cerebro.json`: frequência do colhedor, revisão na sessão, executor e lista de repositórios que agentes podem tocar. Ver `vault/config/README.md`.

## Créditos e inspiração

- Camadas agentes -> loops -> grafos -> autoaperfeiçoamento: setups de Claude Code que circulam entre engenheiros.
- Fila, reconciliação e ADRs: [YudiG12/second-brain-mcp](https://github.com/YudiG12/second-brain-mcp). Aqui a fonte da verdade é uma pasta local com git, com o Obsidian editável.

Licença MIT.
