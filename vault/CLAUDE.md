# Cérebro de trabalho

Este vault do Obsidian, versionado no git, é o segundo cérebro de trabalho do dono. Use-o como fonte de verdade sobre projetos, pessoas, decisões e preferências. Responda em português do Brasil.

## Estrutura

```
inbox/        capturas cruas, ainda sem lugar
notas/        conhecimento: conceitos, como fazer, aprendizados
projetos/     um arquivo por projeto: objetivo, status, próximos passos
decisoes/     ADRs (uma decisão por arquivo)
reunioes/     atas
pessoas/      com quem o dono trabalha e o que cada um cuida
referencias/  links, sistemas internos, documentação
memory/       memória do Claude: um fato por arquivo + MEMORY.md (índice)
propostas/    saída dos loops e agentes esperando aprovação
tarefas/      fila do executor autônomo (ver tarefas/README.md)
evals/        casos de teste para agentes e prompts
config/       cerebro.json: repos e limites do executor
templates/    modelos (nota, projeto, adr, ata, tarefa, CLAUDE-projeto)
indice.md     mapa de conteúdo, ponto de entrada
```

## Regras

1. **Antes de responder** sobre trabalho, projetos ou pessoas, consulte `indice.md`, `memory/MEMORY.md` e as pastas relevantes.
2. **Salve o que é durável** quando for claro na hora (o colhedor também lê a conversa em segundo plano e pega o que escapar, então não interrompa o dono por isso). Decisão vira ADR em `decisoes/`; fato sobre o dono, feedback ou status de projeto vira memória em `memory/` (um fato por arquivo) com uma linha em `memory/MEMORY.md`. Atualize em vez de duplicar.
3. **Formato da memória:**
   ```markdown
   ---
   name: slug-em-kebab-case
   description: uma linha, usada para decidir relevância
   metadata:
     type: user | feedback | project | reference
   ---
   O fato. Em feedback e project, termine com **Why:** e **How to apply:**.
   ```
4. **Frontmatter em toda nota:** `tags`, `criado`, `status` (inbox | rascunho | enriquecida | estavel). Opcionais: `enriquecer: true`, `revisado_em`.
5. **Links** com `[[nome-da-nota]]`. Linke à vontade; link para nota que não existe é lembrete, não erro.
6. **Nomes de arquivo** em kebab-case, minúsculos, sem acento.
7. **Datas absolutas** (AAAA-MM-DD), nunca "ontem".
8. **Nota nova** usa o modelo de `templates/` e entra no `indice.md`.
9. **Nunca grave segredo** (senha, token, chave) em lugar nenhum do vault.
10. **Dado da empresa não sai daqui:** não coloque nomes internos em buscas na web nem em repositórios públicos.
11. **Automático só aplica baixo risco.** O colhedor e os loops gravam sozinhos em `notas/`, `projetos/`, `pessoas/`, `referencias/`, `reunioes/`, `inbox/`, `tarefas/` (rascunho), `indice.md` e `memory/MEMORY.md`. Memórias, `decisoes/`, `CLAUDE.md`, `config/`, `templates/` e `evals/` mudam só com o dono presente (proposta + revisão de um clique). Só o dono muda uma tarefa para `status: pronta`.
12. **Correção que pode se repetir** vira memória e também um caso em `evals/casos/`.
13. Commit e push são feitos pelos hooks; não faça à mão sem pedido.
