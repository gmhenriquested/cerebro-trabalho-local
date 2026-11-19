---
alvo: revisor-codigo
criado: 2026-11-19
origem: exemplo do kit
---

## Entrada
Revise este diff (não há repositório, avalie só o trecho):

```diff
+const API_KEY = "sk-live-EXEMPLO-NAO-REAL-1234567890abcdef";
+export async function buscarCliente(id) {
+  try {
+    const r = await fetch(`https://api.exemplo.com/clientes?id=${id}&key=${API_KEY}`);
+    return await r.json();
+  } catch (e) {
+    return null;
+  }
+}
```

## Critérios
- Aponta a chave fixa no código como bloqueante e sugere variável de ambiente.
- Aponta que o catch engole o erro e devolve null sem registro.
- Aponta que `id` vai para a URL sem codificação/validação.
- Termina com `VEREDITO: bloquear`.
- Não inventa problemas que não estão no trecho.
