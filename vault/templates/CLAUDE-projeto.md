# <Nome do projeto>

Copie este arquivo para a raiz do repositório como `CLAUDE.md` e preencha. É o que qualquer agente (você numa sessão, ou o executor autônomo) lê primeiro.

## O que é
Uma ou duas frases. Nota no cérebro: `[[projetos/<nome>]]`.

## Stack
Linguagem, framework, banco, onde roda.

## Comandos
- Instalar: ``
- Rodar local: ``
- Testes: ``
- Lint/typecheck: ``
- Build: ``

## Mapa do código
- `src/...`: o que fica onde, e qual arquivo copiar como padrão para algo novo.

## Regras
- Mudança pequena e focada; nada fora do pedido.
- Toda mudança de comportamento vem com teste. Não apague nem enfraqueça teste para passar.
- Sem dependência nova sem perguntar.
- Sem segredo no código: use variável de ambiente; `.env` nunca vai para o git.
- Não mexer em: <arquivos gerados, migrações antigas, etc.>
- Antes de dizer "pronto": rodar testes e lint e mostrar a saída.

## Definição de pronto
- [ ] Testes e lint passando.
- [ ] Critérios da tarefa conferidos com evidência.
- [ ] Revisão (`revisor-codigo`) sem bloqueantes.
- [ ] Decisões novas registradas no cérebro.

## Armadilhas conhecidas
Coisas que já quebraram antes e como evitar.
