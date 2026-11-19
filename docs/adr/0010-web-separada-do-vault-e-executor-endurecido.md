# ADR 0010: web separada do vault, tarefa decidida pelo resultado e executor endurecido

- **Status:** aceita
- **Data:** 2026-11-19

## Contexto
Uma revisão de segurança achou três pontos:

1. **Tarefa liberada por agente.** A guarda procurava `status: pronta` só no trecho novo de um Edit. Um Edit que troca apenas a palavra `rascunho` por `pronta` não tem `status:` no trecho e passava. Como o noturno e o colhedor podem escrever em `tarefas/`, um agente sem o dono conseguiria liberar uma tarefa para o executor. Também era possível reescrever o corpo de uma tarefa que o dono já tinha liberado.
2. **Noturno com as três peças perigosas juntas.** Ele lia o vault (dado privado), abria páginas da web (conteúdo não confiável) e podia mandar dados para fora pela própria busca ou pelo endereço do WebFetch. Uma página maliciosa podia pedir isso, e a lista de termos internos não segura texto codificado ou partido.
3. **Executor rodando código do agente com o seu usuário.** A guarda limita onde o Claude escreve, mas o agente podia mudar o que roda: `package.json` (scripts do `npm test`), hooks do git ou do husky, workflows do CI. No nível 2, o push dispara o CI com esse código.

## Decisão
1. **A guarda decide pelo resultado.** Em modo autônomo, para arquivos em `tarefas/`, ela simula o Write, Edit ou MultiEdit sobre o arquivo atual e lê o frontmatter de como ficaria. Só passa se o resultado continuar `status: rascunho`. Tarefa que já não está em rascunho (pronta, fazendo, revisar, feita, bloqueada) não é tocada por agente nenhum. Se não der para simular, nega.
2. **Quem lê o vault não tem web; quem tem web não lê o vault.** O noturno roda sem WebSearch e WebFetch e, para cada nota marcada, escreve até 3 perguntas genéricas numa seção `## Pesquisas pedidas`. O script confere se a nota estava mesmo marcada, veta perguntas com termo interno ou com cara de segredo e chama um pesquisador (`prompts/pesquisa-web.md`, papel `pesquisa_web`) só com WebSearch e WebFetch, numa pasta vazia, sem raiz de escrita. O próprio script anexa o resultado na nota, com o aviso de que veio da web, e atualiza o frontmatter. Nenhum modelo com permissão de escrita lê texto da web.
3. **Executor endurecido.**
   - A guarda nega, em modo autônomo, escrita em arquivos que fazem código rodar sozinho: `.git`, `.github`, `.husky`, `.vscode`, `.idea`, `.claude`, `.devcontainer`, `.circleci`, `.gitlab`, `package.json`, `.npmrc`, `.yarnrc`, `.gitattributes`, `.gitmodules`, `Makefile`, `nuget.config` e parecidos. Dependência nova e mudança de CI ficam com o dono, descritas no relatório.
   - O executor confere o diff antes de verificar. Se a branch mexe num desses arquivos (por qualquer caminho), a verificação não roda, a tarefa fica `bloqueada` e não há push.
   - A verificação roda sem as variáveis de ambiente com cara de credencial (`*TOKEN*`, `*SECRET*`, `*_KEY`, `GH_*`, `GITHUB_*`, `AWS_*`, `ANTHROPIC_*`, `NPM_*` e outras). Elas voltam logo depois.
4. **Teste da guarda.** `scripts/windows/testar-guarda.ps1` cobre os casos acima e os bloqueios antigos.

## Limites que continuam
- Os testes do repositório são código, e o agente pode escrever testes. Quem roda `npm test` roda código do agente com o seu usuário e alcança seus arquivos (não as variáveis removidas). Isolamento de verdade continua sendo WSL2 com o sandbox do Claude Code, ou outro usuário do Windows sem credenciais (ADR 0005, roadmap).
- No nível 2, o CI do repositório roda o código da branch `agente/*`. Configure os workflows para não expor segredos a essas branches.
- O pesquisador web recebe o `~/.claude/CLAUDE.md` global, como toda sessão. Não coloque dado da empresa nele.
- Quem consegue dar push no remoto do vault controla `config/cerebro.json`, inclusive o comando de verificação do executor. O remoto do vault tem que ser privado e só seu.
- O colhedor ainda grava sozinho em `memory/MEMORY.md` a partir das suas conversas. Ele só lê o texto das falas (sem resultado de ferramenta), mas uma resposta do Claude que repita uma página pode chegar lá. O semanal relê o que foi aplicado.

## Consequências
- O noturno pode precisar de duas chamadas a mais por nota marcada (pesquisa), com o modelo do papel `pesquisa_web`.
- Tarefas mexidas por agente sempre voltam em rascunho; o dono libera.
- Um falso positivo da lista de arquivos sensíveis vira tarefa bloqueada com o motivo no relatório. Ajuste a lista na guarda e no executor juntos.
