-- =============================================================================
-- SisGESC — Sistema de Gestão Educacional
-- Script DDL — Fase 1: Fundação e Modelagem Transacional
-- UNICID — Universidade Cidade de São Paulo
-- Curso: Ciência da Computação | Disciplina: Banco de Dados | 2026
-- Avaliação Cega — sem identificação dos integrantes
-- =============================================================================
-- Padrões adotados:
--   snake_case para todos os identificadores
--   Prefixo tb_  → tabelas
--   Prefixo pk_  → chaves primárias
--   Prefixo fk_  → chaves estrangeiras
--   DECIMAL(10,2) → valores financeiros
--   DATE          → datas
--   TIMESTAMP     → auditoria (data_criacao, ultima_atualizacao)
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- ORDEM DE CRIAÇÃO:
--   1. Tabelas base (sem dependências externas)
--   2. Tabelas com FK para tabelas base
--   3. Tabelas associativas / dependentes
-- ─────────────────────────────────────────────────────────────────────────────


-- =============================================================================
-- MÓDULO ACADÊMICO
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. tb_cursos
--    Base: não depende de nenhuma outra tabela
-- -----------------------------------------------------------------------------
CREATE TABLE tb_cursos (
    pk_id_curso    INT            NOT NULL AUTO_INCREMENT,
    nome_curso     VARCHAR(100)   NOT NULL,
    modalidade     VARCHAR(20)    NOT NULL,
    carga_horaria  INT            NOT NULL,
    nivel          VARCHAR(30)    NOT NULL,
    ativo          BOOLEAN        NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_cursos        PRIMARY KEY (pk_id_curso),
    CONSTRAINT chk_modalidade   CHECK (modalidade IN ('Presencial', 'EAD', 'Híbrido')),
    CONSTRAINT chk_nivel        CHECK (nivel IN ('Graduação', 'Pós-Graduação', 'Técnico')),
    CONSTRAINT chk_carga_curso  CHECK (carga_horaria > 0)
);

-- -----------------------------------------------------------------------------
-- 2. tb_alunos
--    Base: não depende de nenhuma outra tabela
-- -----------------------------------------------------------------------------
CREATE TABLE tb_alunos (
    pk_rgm               INT            NOT NULL AUTO_INCREMENT,
    nome_aluno           VARCHAR(120)   NOT NULL,
    data_nascimento      DATE           NOT NULL,
    cpf                  VARCHAR(11)    NOT NULL,
    email                VARCHAR(150)   NOT NULL,
    telefone             VARCHAR(15)    NOT NULL,
    status_aluno         VARCHAR(20)    NOT NULL DEFAULT 'Ativo',
    data_criacao         TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ultima_atualizacao   TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                                 ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_alunos         PRIMARY KEY (pk_rgm),
    CONSTRAINT uq_aluno_cpf      UNIQUE (cpf),
    CONSTRAINT uq_aluno_email    UNIQUE (email),
    CONSTRAINT chk_status_aluno  CHECK (status_aluno IN ('Ativo','Trancado','Formado','Evadido'))
);

-- -----------------------------------------------------------------------------
-- 3. tb_disciplinas
--    Depende de: tb_cursos
-- -----------------------------------------------------------------------------
CREATE TABLE tb_disciplinas (
    pk_id_disciplina  INT            NOT NULL AUTO_INCREMENT,
    fk_id_curso       INT            NOT NULL,
    nome_disciplina   VARCHAR(100)   NOT NULL,
    carga_horaria     INT            NOT NULL,
    semestre          INT            NOT NULL,
    creditos          INT            NOT NULL,
    ementa            TEXT,

    CONSTRAINT pk_disciplinas       PRIMARY KEY (pk_id_disciplina),
    CONSTRAINT fk_disc_curso        FOREIGN KEY (fk_id_curso)
                                    REFERENCES tb_cursos (pk_id_curso),
    CONSTRAINT chk_carga_disc       CHECK (carga_horaria > 0),
    CONSTRAINT chk_semestre_disc    CHECK (semestre > 0),
    CONSTRAINT chk_creditos         CHECK (creditos > 0)
);

-- -----------------------------------------------------------------------------
-- 4. tb_turmas
--    Depende de: tb_disciplinas
-- -----------------------------------------------------------------------------
CREATE TABLE tb_turmas (
    pk_id_turma      INT            NOT NULL AUTO_INCREMENT,
    fk_id_disciplina INT            NOT NULL,
    codigo_turma     VARCHAR(20)    NOT NULL,
    ano              INT            NOT NULL,
    semestre_letivo  INT            NOT NULL,
    vagas            INT            NOT NULL,
    vagas_ocupadas   INT            NOT NULL DEFAULT 0,

    CONSTRAINT pk_turmas              PRIMARY KEY (pk_id_turma),
    CONSTRAINT fk_turma_disciplina    FOREIGN KEY (fk_id_disciplina)
                                      REFERENCES tb_disciplinas (pk_id_disciplina),
    CONSTRAINT uq_codigo_turma        UNIQUE (codigo_turma),
    CONSTRAINT chk_semestre_letivo    CHECK (semestre_letivo IN (1, 2)),
    CONSTRAINT chk_vagas              CHECK (vagas > 0),
    CONSTRAINT chk_vagas_ocupadas     CHECK (vagas_ocupadas >= 0),
    CONSTRAINT chk_vagas_limite       CHECK (vagas_ocupadas <= vagas)
);

-- -----------------------------------------------------------------------------
-- 5. tb_grade_horaria
--    Depende de: tb_turmas
-- -----------------------------------------------------------------------------
CREATE TABLE tb_grade_horaria (
    pk_id_grade      INT            NOT NULL AUTO_INCREMENT,
    fk_id_turma      INT            NOT NULL,
    dia_semana       VARCHAR(15)    NOT NULL,
    horario_inicio   TIME           NOT NULL,
    horario_fim      TIME           NOT NULL,
    sala             VARCHAR(20)    NOT NULL,

    CONSTRAINT pk_grade_horaria   PRIMARY KEY (pk_id_grade),
    CONSTRAINT fk_grade_turma     FOREIGN KEY (fk_id_turma)
                                  REFERENCES tb_turmas (pk_id_turma),
    CONSTRAINT chk_dia_semana     CHECK (dia_semana IN
                                  ('Segunda','Terça','Quarta','Quinta','Sexta','Sábado')),
    CONSTRAINT chk_horario        CHECK (horario_fim > horario_inicio)
);

-- -----------------------------------------------------------------------------
-- 6. tb_matriculas  ← ENTIDADE ASSOCIATIVA N:N (alunos × turmas)
--    Depende de: tb_alunos, tb_turmas
-- -----------------------------------------------------------------------------
CREATE TABLE tb_matriculas (
    pk_id_matricula   INT            NOT NULL AUTO_INCREMENT,
    fk_rgm            INT            NOT NULL,
    fk_id_turma       INT            NOT NULL,
    data_matricula    DATE           NOT NULL,
    status_matricula  VARCHAR(20)    NOT NULL DEFAULT 'Ativa',
    data_criacao      TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_matriculas          PRIMARY KEY (pk_id_matricula),
    CONSTRAINT fk_mat_aluno           FOREIGN KEY (fk_rgm)
                                      REFERENCES tb_alunos (pk_rgm),
    CONSTRAINT fk_mat_turma           FOREIGN KEY (fk_id_turma)
                                      REFERENCES tb_turmas (pk_id_turma),
    CONSTRAINT uq_aluno_turma         UNIQUE (fk_rgm, fk_id_turma),
    CONSTRAINT chk_status_matricula   CHECK (status_matricula IN
                                      ('Ativa','Trancada','Cancelada','Concluída'))
);

-- -----------------------------------------------------------------------------
-- 7. tb_notas
--    Depende de: tb_matriculas
-- -----------------------------------------------------------------------------
CREATE TABLE tb_notas (
    pk_id_nota           INT             NOT NULL AUTO_INCREMENT,
    fk_id_matricula      INT             NOT NULL,
    nota_1               DECIMAL(4,2),
    nota_2               DECIMAL(4,2),
    nota_final           DECIMAL(4,2),
    situacao             VARCHAR(20)     NOT NULL DEFAULT 'Em Curso',
    ultima_atualizacao   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
                                                  ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_notas         PRIMARY KEY (pk_id_nota),
    CONSTRAINT fk_nota_mat      FOREIGN KEY (fk_id_matricula)
                                REFERENCES tb_matriculas (pk_id_matricula),
    CONSTRAINT chk_nota_1       CHECK (nota_1 BETWEEN 0 AND 10),
    CONSTRAINT chk_nota_2       CHECK (nota_2 BETWEEN 0 AND 10),
    CONSTRAINT chk_nota_final   CHECK (nota_final BETWEEN 0 AND 10),
    CONSTRAINT chk_situacao     CHECK (situacao IN
                                ('Aprovado','Reprovado','Em Curso','Reprovado por Falta'))
);

-- -----------------------------------------------------------------------------
-- 8. tb_faltas
--    Depende de: tb_matriculas
-- -----------------------------------------------------------------------------
CREATE TABLE tb_faltas (
    pk_id_falta      INT       NOT NULL AUTO_INCREMENT,
    fk_id_matricula  INT       NOT NULL,
    data_aula        DATE      NOT NULL,
    justificada      BOOLEAN   NOT NULL DEFAULT FALSE,
    total_faltas     INT       NOT NULL DEFAULT 0,

    CONSTRAINT pk_faltas         PRIMARY KEY (pk_id_falta),
    CONSTRAINT fk_falta_mat      FOREIGN KEY (fk_id_matricula)
                                 REFERENCES tb_matriculas (pk_id_matricula),
    CONSTRAINT chk_total_faltas  CHECK (total_faltas >= 0)
);


-- =============================================================================
-- MÓDULO FINANCEIRO EDUCACIONAL
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 9. tb_contratos_educacionais
--    Depende de: tb_alunos, tb_cursos
-- -----------------------------------------------------------------------------
CREATE TABLE tb_contratos_educacionais (
    pk_id_contrato       INT             NOT NULL AUTO_INCREMENT,
    fk_rgm               INT             NOT NULL,
    fk_id_curso          INT             NOT NULL,
    data_inicio          DATE            NOT NULL,
    data_fim             DATE            NOT NULL,
    valor_total          DECIMAL(10,2)   NOT NULL,
    num_parcelas         INT             NOT NULL,
    status_contrato      VARCHAR(20)     NOT NULL DEFAULT 'Ativo',
    data_criacao         TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ultima_atualizacao   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
                                                  ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_contratos           PRIMARY KEY (pk_id_contrato),
    CONSTRAINT fk_cont_aluno          FOREIGN KEY (fk_rgm)
                                      REFERENCES tb_alunos (pk_rgm),
    CONSTRAINT fk_cont_curso          FOREIGN KEY (fk_id_curso)
                                      REFERENCES tb_cursos (pk_id_curso),
    CONSTRAINT chk_valor_contrato     CHECK (valor_total > 0),
    CONSTRAINT chk_num_parcelas       CHECK (num_parcelas > 0),
    CONSTRAINT chk_datas_contrato     CHECK (data_fim > data_inicio),
    CONSTRAINT chk_status_contrato    CHECK (status_contrato IN ('Ativo','Encerrado','Suspenso'))
);

-- -----------------------------------------------------------------------------
-- 10. tb_mensalidades
--     Depende de: tb_contratos_educacionais
-- -----------------------------------------------------------------------------
CREATE TABLE tb_mensalidades (
    pk_id_mensalidade   INT             NOT NULL AUTO_INCREMENT,
    fk_id_contrato      INT             NOT NULL,
    numero_parcela      INT             NOT NULL,
    valor               DECIMAL(10,2)   NOT NULL,
    data_vencimento     DATE            NOT NULL,
    status_pagamento    VARCHAR(20)     NOT NULL DEFAULT 'Pendente',
    data_criacao        TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_mensalidades        PRIMARY KEY (pk_id_mensalidade),
    CONSTRAINT fk_mens_contrato       FOREIGN KEY (fk_id_contrato)
                                      REFERENCES tb_contratos_educacionais (pk_id_contrato),
    CONSTRAINT uq_parcela_contrato    UNIQUE (fk_id_contrato, numero_parcela),
    CONSTRAINT chk_valor_mens         CHECK (valor > 0),
    CONSTRAINT chk_numero_parcela     CHECK (numero_parcela > 0),
    CONSTRAINT chk_status_pagamento   CHECK (status_pagamento IN
                                      ('Pendente','Pago','Vencido','Cancelado'))
);

-- -----------------------------------------------------------------------------
-- 11. tb_pagamentos
--     Depende de: tb_mensalidades
-- -----------------------------------------------------------------------------
CREATE TABLE tb_pagamentos (
    pk_id_pagamento   INT             NOT NULL AUTO_INCREMENT,
    fk_id_mensalidade INT             NOT NULL,
    data_pagamento    DATE            NOT NULL,
    valor_pago        DECIMAL(10,2)   NOT NULL,
    forma_pagamento   VARCHAR(30)     NOT NULL,
    data_criacao      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_pagamentos          PRIMARY KEY (pk_id_pagamento),
    CONSTRAINT fk_pag_mensalidade     FOREIGN KEY (fk_id_mensalidade)
                                      REFERENCES tb_mensalidades (pk_id_mensalidade),
    CONSTRAINT chk_valor_pago         CHECK (valor_pago > 0),
    CONSTRAINT chk_forma_pagamento    CHECK (forma_pagamento IN
                                      ('Boleto','Cartão','PIX','Transferência'))
);

-- -----------------------------------------------------------------------------
-- 12. tb_inadimplencia
--     Depende de: tb_mensalidades
-- -----------------------------------------------------------------------------
CREATE TABLE tb_inadimplencia (
    pk_id_inadimplencia  INT             NOT NULL AUTO_INCREMENT,
    fk_id_mensalidade    INT             NOT NULL,
    dias_atraso          INT             NOT NULL,
    multa                DECIMAL(10,2)   NOT NULL DEFAULT 0.00,
    juros                DECIMAL(10,2)   NOT NULL DEFAULT 0.00,
    status_negociacao    VARCHAR(30)     NOT NULL DEFAULT 'Em Aberto',
    data_registro        TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_inadimplencia         PRIMARY KEY (pk_id_inadimplencia),
    CONSTRAINT fk_inadim_mensalidade    FOREIGN KEY (fk_id_mensalidade)
                                        REFERENCES tb_mensalidades (pk_id_mensalidade),
    CONSTRAINT chk_dias_atraso          CHECK (dias_atraso >= 0),
    CONSTRAINT chk_multa                CHECK (multa >= 0),
    CONSTRAINT chk_juros                CHECK (juros >= 0),
    CONSTRAINT chk_status_negociacao    CHECK (status_negociacao IN
                                        ('Em Aberto','Negociando','Acordado','Quitado'))
);

-- -----------------------------------------------------------------------------
-- 13. tb_contas_receber
--     Depende de: tb_contratos_educacionais
-- -----------------------------------------------------------------------------
CREATE TABLE tb_contas_receber (
    pk_id_conta_rec   INT             NOT NULL AUTO_INCREMENT,
    fk_id_contrato    INT             NOT NULL,
    descricao         VARCHAR(200)    NOT NULL,
    valor             DECIMAL(10,2)   NOT NULL,
    data_vencimento   DATE            NOT NULL,
    status            VARCHAR(20)     NOT NULL DEFAULT 'Aberto',

    CONSTRAINT pk_contas_receber    PRIMARY KEY (pk_id_conta_rec),
    CONSTRAINT fk_crec_contrato     FOREIGN KEY (fk_id_contrato)
                                    REFERENCES tb_contratos_educacionais (pk_id_contrato),
    CONSTRAINT chk_valor_crec       CHECK (valor > 0),
    CONSTRAINT chk_status_crec      CHECK (status IN ('Aberto','Recebido','Cancelado'))
);

-- -----------------------------------------------------------------------------
-- 14. tb_contas_pagar
--     Sem dependências externas (despesas institucionais)
-- -----------------------------------------------------------------------------
CREATE TABLE tb_contas_pagar (
    pk_id_conta_pag   INT             NOT NULL AUTO_INCREMENT,
    descricao         VARCHAR(200)    NOT NULL,
    fornecedor        VARCHAR(150)    NOT NULL,
    valor             DECIMAL(10,2)   NOT NULL,
    data_vencimento   DATE            NOT NULL,
    status            VARCHAR(20)     NOT NULL DEFAULT 'Aberto',
    data_pagamento    DATE,

    CONSTRAINT pk_contas_pagar    PRIMARY KEY (pk_id_conta_pag),
    CONSTRAINT chk_valor_cpag     CHECK (valor > 0),
    CONSTRAINT chk_status_cpag    CHECK (status IN ('Aberto','Pago','Cancelado'))
);


-- =============================================================================
-- MÓDULO DE RECURSOS HUMANOS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 15. tb_funcionarios
--     Base: não depende de nenhuma outra tabela
-- -----------------------------------------------------------------------------
CREATE TABLE tb_funcionarios (
    pk_id_funcionario    INT             NOT NULL AUTO_INCREMENT,
    nome_funcionario     VARCHAR(120)    NOT NULL,
    cpf                  VARCHAR(11)     NOT NULL,
    data_nascimento      DATE            NOT NULL,
    email_corporativo    VARCHAR(150)    NOT NULL,
    cargo                VARCHAR(80)     NOT NULL,
    salario              DECIMAL(10,2)   NOT NULL,
    data_admissao        DATE            NOT NULL,
    status_func          VARCHAR(20)     NOT NULL DEFAULT 'Ativo',
    data_criacao         TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_funcionarios       PRIMARY KEY (pk_id_funcionario),
    CONSTRAINT uq_func_cpf           UNIQUE (cpf),
    CONSTRAINT uq_func_email         UNIQUE (email_corporativo),
    CONSTRAINT chk_salario           CHECK (salario > 0),
    CONSTRAINT chk_status_func       CHECK (status_func IN ('Ativo','Afastado','Desligado'))
);

-- -----------------------------------------------------------------------------
-- 16. tb_professores
--     Especialização de tb_funcionarios (herança 1:1)
--     Depende de: tb_funcionarios
-- -----------------------------------------------------------------------------
CREATE TABLE tb_professores (
    pk_fk_id_funcionario  INT            NOT NULL,
    titulacao             VARCHAR(40)    NOT NULL,
    area_atuacao          VARCHAR(100)   NOT NULL,
    lattes                VARCHAR(200),
    regime_trabalho       VARCHAR(20)    NOT NULL,

    CONSTRAINT pk_professores         PRIMARY KEY (pk_fk_id_funcionario),
    CONSTRAINT fk_prof_funcionario    FOREIGN KEY (pk_fk_id_funcionario)
                                      REFERENCES tb_funcionarios (pk_id_funcionario),
    CONSTRAINT chk_titulacao          CHECK (titulacao IN
                                      ('Graduação','Especialização','Mestrado','Doutorado')),
    CONSTRAINT chk_regime             CHECK (regime_trabalho IN ('Integral','Parcial','Horista'))
);

-- -----------------------------------------------------------------------------
-- 17. tb_vinculos_professor_disciplina  ← ENTIDADE ASSOCIATIVA N:N (professores × turmas)
--     Depende de: tb_professores, tb_turmas
-- -----------------------------------------------------------------------------
CREATE TABLE tb_vinculos_professor_disciplina (
    pk_id_vinculo    INT      NOT NULL AUTO_INCREMENT,
    fk_id_professor  INT      NOT NULL,
    fk_id_turma      INT      NOT NULL,
    data_inicio      DATE     NOT NULL,
    data_fim         DATE,
    ativo            BOOLEAN  NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_vinculos            PRIMARY KEY (pk_id_vinculo),
    CONSTRAINT fk_vinc_professor      FOREIGN KEY (fk_id_professor)
                                      REFERENCES tb_professores (pk_fk_id_funcionario),
    CONSTRAINT fk_vinc_turma          FOREIGN KEY (fk_id_turma)
                                      REFERENCES tb_turmas (pk_id_turma),
    CONSTRAINT uq_vinculo_ativo       UNIQUE (fk_id_professor, fk_id_turma, ativo),
    CONSTRAINT chk_datas_vinculo      CHECK (data_fim IS NULL OR data_fim >= data_inicio)
);

-- -----------------------------------------------------------------------------
-- 18. tb_carga_horaria_docente
--     Depende de: tb_professores, tb_turmas
-- -----------------------------------------------------------------------------
CREATE TABLE tb_carga_horaria_docente (
    pk_id_carga      INT   NOT NULL AUTO_INCREMENT,
    fk_id_professor  INT   NOT NULL,
    fk_id_turma      INT   NOT NULL,
    horas_semanais   INT   NOT NULL,
    mes_referencia   INT   NOT NULL,
    ano_referencia   INT   NOT NULL,

    CONSTRAINT pk_carga_horaria       PRIMARY KEY (pk_id_carga),
    CONSTRAINT fk_carga_professor     FOREIGN KEY (fk_id_professor)
                                      REFERENCES tb_professores (pk_fk_id_funcionario),
    CONSTRAINT fk_carga_turma         FOREIGN KEY (fk_id_turma)
                                      REFERENCES tb_turmas (pk_id_turma),
    CONSTRAINT chk_horas_semanais     CHECK (horas_semanais > 0),
    CONSTRAINT chk_mes_ref            CHECK (mes_referencia BETWEEN 1 AND 12),
    CONSTRAINT chk_ano_ref            CHECK (ano_referencia >= 2020)
);


-- =============================================================================
-- FIM DO SCRIPT DDL — SisGESC Fase 1
-- =============================================================================
-- Resumo de tabelas criadas (18 no total):
--
-- MÓDULO ACADÊMICO (8):
--   tb_cursos, tb_alunos, tb_disciplinas, tb_turmas,
--   tb_grade_horaria, tb_matriculas (*), tb_notas, tb_faltas
--
-- MÓDULO FINANCEIRO (6):
--   tb_contratos_educacionais, tb_mensalidades, tb_pagamentos,
--   tb_inadimplencia, tb_contas_receber, tb_contas_pagar
--
-- MÓDULO DE RECURSOS HUMANOS (4):
--   tb_funcionarios, tb_professores,
--   tb_vinculos_professor_disciplina (*), tb_carga_horaria_docente
--
-- (*) Entidades associativas que resolvem relacionamentos N:N
-- =============================================================================
