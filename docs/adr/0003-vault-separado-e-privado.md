# ADR 0003: kit público, vault separado e privado

- **Status:** aceita
- **Data:** 2026-11-19

## Contexto
O kit é útil para qualquer pessoa, mas o vault de trabalho tem informação da empresa.

## Decisão
Este repositório só tem estrutura, scripts, agentes e documentação genérica. O vault de cada pessoa é outro repositório, privado, no lugar que a empresa permitir. Nada de MCP remoto em serviço pessoal para dado da empresa.

## Consequências
- Adaptações específicas (agentes do domínio, pastas extras) ficam no vault.
- Melhorias genéricas voltam para o kit com um ADR.
- Buscas na web feitas pelos agentes não podem levar nomes internos.
