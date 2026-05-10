# SisGESC — Sistema de Gestão Educacional
**Projeto de Banco de Dados | UNICID — Ciência da Computação | 2026**

> Avaliação cega — sem identificação dos integrantes.

---

## Sobre o projeto

O SisGESC é um ERP educacional modelado para uma universidade privada de médio porte. O banco cobre três módulos operacionais (OLTP) e um modelo dimensional de análise (OLAP/Star Schema).

---

## Estrutura do repositório

```
sisgesc/
├── sisgesc_fase1_final.sql        # DDL completo — estrutura OLTP + VIEWs
├── sisgesc_fase2_corrigido.sql    # DML + OLTP + Star Schema + ETL + Índices
├── sisgesc_correcoes_finais.sql   # Fix idempotência + fato_desempenho + reset
└── README.md
```

---

## Como executar

### Pré-requisito
MySQL 8.0+ ou MariaDB 10.6+

### Execução completa (na ordem)

```sql
-- 1. Cria toda a estrutura OLTP (tabelas + views)
source sisgesc_fase1_final.sql;

-- 2. Insere dados + cria OLAP (dims + fatos + ETL + índices)
source sisgesc_fase2_corrigido.sql;

-- 3. Aplica correções finais (idempotência + fato_desempenho + reset)
source sisgesc_correcoes_finais.sql;
```

### Verificação rápida

```sql
-- Confirma tabelas criadas
SHOW TABLES;

-- Confirma contagem de registros
SELECT 'tb_alunos', COUNT(*) FROM tb_alunos
UNION ALL SELECT 'tb_mensalidades', COUNT(*) FROM tb_mensalidades
UNION ALL SELECT 'fato_financeiro', COUNT(*) FROM fato_financeiro
UNION ALL SELECT 'fato_desempenho', COUNT(*) FROM fato_desempenho;
```

---

## Arquitetura

### OLTP — Módulos operacionais

| Módulo | Tabelas principais |
|---|---|
| Acadêmico | `tb_alunos`, `tb_turmas`, `tb_matriculas`, `tb_notas`, `tb_faltas` |
| Financeiro | `tb_contratos`, `tb_mensalidades`, `tb_pagamentos`, `tb_inadimplencia` |
| RH | `tb_funcionarios`, `tb_professores`, `tb_folha_pagamento`, `tb_vinculos` |

### OLAP — Star Schema

Dois processos de negócio modelados em tabelas fato separadas:

```
dim_aluno ──┬── fato_financeiro ──┬── dim_tempo
            │                    ├── dim_curso
            │                    └── dim_unidade
            │
            └── fato_desempenho ──── dim_disciplina
                                └── dim_tempo  (conformada)
```

**dim_aluno** e **dim_tempo** são dimensões conformadas — conectam as duas fatos, permitindo análises cruzadas como "alunos inadimplentes têm pior desempenho acadêmico?"

---

## Padrões adotados

- `snake_case` em todos os identificadores
- Prefixo `tb_` → tabelas OLTP
- Prefixo `pk_` → chaves primárias (constraints nomeadas)
- Prefixo `fk_` → chaves estrangeiras (constraints nomeadas)
- Prefixo `sk_` → surrogate keys nas dimensões OLAP
- `DECIMAL(10,2)` → valores financeiros
- Campos calculados substituídos por VIEWs (3FN)

---

## Correções aplicadas (feedback Fase 1)

| Problema apontado | Correção aplicada |
|---|---|
| Texto fora de comentários no SQL | Todo texto em blocos `--` |
| `nome_aluno` violava 1FN | Separado em `primeiro_nome` + `sobrenome` |
| `email`/`telefone` multivalorado | Tabelas próprias `tb_emails_alunos`, `tb_telefones_alunos` |
| `titulacao` multivalorada | Tabela `tb_titulacoes_professor` |
| Campos calculados violando 3FN | Substituídos por VIEWs (`vw_notas_finais`, etc.) |
| PK artificial nas associativas | `tb_matriculas` e `tb_vinculos` com PK composta física |
