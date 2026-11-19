---
name: capturar
description: Joga uma ideia, link, anotação ou trecho de conversa no inbox do cérebro de trabalho, sem precisar decidir onde fica. Use quando disserem /capturar, "anota isso", "guarda isso no cérebro" ou "joga no inbox".
---

# Capturar

1. Pegue o texto passado como argumento. Se não houver, use o trecho relevante da conversa atual e confirme em uma linha o que vai capturar.
2. Grave em `inbox/AAAA-MM-DD-HHMM-<slug-curto>.md` no vault:
   ```markdown
   ---
   tags: [inbox]
   criado: AAAA-MM-DD
   status: inbox
   origem: <conversa | link | reunião | ideia>
   ---

   <o conteúdo, sem reescrever demais>

   Contexto: <uma linha dizendo de onde veio, se ajudar>
   ```
3. Mascare qualquer segredo. Não pesquise, não organize: a triagem faz isso depois.
4. Responda só com o caminho do arquivo.
