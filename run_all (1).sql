-- =============================================================================
-- SisGESC -- Sistema de Gestao Educacional
-- SCRIPT UNICO DE INSTALACAO: run_all.sql
-- UNICID -- Universidade Cidade de Sao Paulo
-- Curso: Ciencia da Computacao | Disciplina: Banco de Dados | 2026
-- Avaliacao Cega -- sem identificacao dos integrantes
-- =============================================================================
--
-- COMO EXECUTAR:
--   mysql -u root -p < run_all.sql
--   OU dentro do MySQL Workbench: File > Run SQL Script > run_all.sql
--
-- ORDEM DO SCRIPT:
--   PARTE 1: DDL -- criacao do banco e tabelas (OLTP)
--   PARTE 2: DML -- carga de dados com idempotencia
--   PARTE 3: VALIDACAO -- SELECT COUNT(*) antes e depois
--   PARTE 4: OLTP -- consultas, subselects, transacoes
--   PARTE 5: OLAP -- Star Schema (dims + fatos + ETL)
--   PARTE 6: VALIDACAO OLTP vs OLAP
--   PARTE 7: PERFORMANCE -- indices + EXPLAIN
--   PARTE 8: RESET -- script de limpeza sem destruir estrutura
--
-- =============================================================================
-- CORRECOES DO FEEDBACK DA FASE 1 (todas aplicadas):
--   [C1] nome_aluno decomposto em primeiro_nome + sobrenome
--   [C2] email e telefone em tabelas proprias (1FN)
--   [C3] titulacao do professor em tabela propria (multivalorado, 1FN)
--   [C4] campos calculados removidos -- substituidos por VIEWs (3FN)
--        nota_final -> vw_notas_finais
--        total_faltas -> vw_frequencia
--        vagas_ocupadas -> vw_ocupacao_turmas
--        valor_total -> vw_contratos_valor
--        multa e juros -> vw_inadimplencia_encargos
--   [C5] entidades associativas com PK composta fisica
--   [C6] script 100% executavel -- sem texto puro fora de comentarios
--   [C7] tb_folha_pagamento adicionada (sugestao do professor)
--   [C8] tb_turma_disciplina resolve multivalorado de turma x disciplina
--   [C9] links do GitHub e DER presentes no PDF de documentacao
-- =============================================================================

SET SESSION sql_mode = 'STRICT_TRANS_TABLES,STRICT_ALL_TABLES,TRADITIONAL';
DROP DATABASE IF EXISTS sisgesc;
CREATE DATABASE sisgesc CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE sisgesc;


-- =============================================================================
-- PARTE 1 -- DDL: CRIACAO DAS TABELAS (OLTP)
-- =============================================================================
--
-- [LEMBRETE DO GRUPO]
-- Esta parte cria a estrutura do banco. Nao tem dados ainda.
-- Se o professor perguntar: "Por que essa ordem?"
-- Resposta: tabelas sem FK primeiro, depois as que dependem delas.
-- Exemplo: tb_alunos nao depende de nada. tb_matriculas depende de
-- tb_alunos e tb_turmas, entao vem depois.
-- =============================================================================


-- =============================================================================
-- MODULO ACADEMICO
-- =============================================================================

-- [LEMBRETE DO GRUPO]
-- Modulo academico: tudo que envolve o aluno dentro da escola.
-- Ciclo: aluno -> se matricula em turma -> recebe notas -> acumula faltas.
-- tb_curso_disciplina e tb_turma_disciplina resolvem o erro de 1FN:
-- uma turma pode ter varias disciplinas (N:N).

-- -----------------------------------------------------------------------------
-- tb_cursos
-- -----------------------------------------------------------------------------
CREATE TABLE tb_cursos (
    pk_id_curso    INT          NOT NULL AUTO_INCREMENT,
    nome_curso     VARCHAR(100) NOT NULL,
    modalidade     VARCHAR(20)  NOT NULL,
    carga_horaria  INT          NOT NULL,
    nivel          VARCHAR(30)  NOT NULL,
    ativo          BOOLEAN      NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_cursos       PRIMARY KEY (pk_id_curso),
    CONSTRAINT chk_modalidade  CHECK (modalidade IN ('Presencial', 'EAD', 'Hibrido')),
    CONSTRAINT chk_nivel       CHECK (nivel IN ('Graduacao', 'Pos-Graduacao', 'Tecnico')),
    CONSTRAINT chk_carga_curso CHECK (carga_horaria > 0)
);

-- -----------------------------------------------------------------------------
-- tb_alunos
-- [C1] primeiro_nome + sobrenome (nao mais nome_aluno -- correcao de 1FN)
-- [C2] email e telefone foram movidos para tabelas proprias
-- -----------------------------------------------------------------------------
CREATE TABLE tb_alunos (
    pk_rgm             INT         NOT NULL AUTO_INCREMENT,
    primeiro_nome      VARCHAR(60) NOT NULL,
    sobrenome          VARCHAR(60) NOT NULL,
    nascimento         DATE        NOT NULL,
    cpf                VARCHAR(11) NOT NULL,
    status_aluno       VARCHAR(20) NOT NULL DEFAULT 'Ativo',
    criado_em          TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
                                            ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_alunos        PRIMARY KEY (pk_rgm),
    CONSTRAINT uq_aluno_cpf     UNIQUE (cpf),
    CONSTRAINT chk_status_aluno CHECK (status_aluno IN ('Ativo','Trancado','Formado','Evadido'))
);

-- -----------------------------------------------------------------------------
-- tb_emails_alunos
-- [C2] atributo multivalorado -- 1FN corrigida
-- [LEMBRETE DO GRUPO] Por que tabela separada?
-- Um aluno pode ter mais de um email (pessoal + institucional).
-- Se ficasse uma coluna so, violaria a 1FN (atributo multivalorado).
-- -----------------------------------------------------------------------------
CREATE TABLE tb_emails_alunos (
    pk_id_email  INT          NOT NULL AUTO_INCREMENT,
    fk_aluno_id  INT          NOT NULL,
    email        VARCHAR(150) NOT NULL,
    tipo         VARCHAR(20)  NOT NULL DEFAULT 'Pessoal',

    CONSTRAINT pk_emails_alunos  PRIMARY KEY (pk_id_email),
    CONSTRAINT fk_email_aluno    FOREIGN KEY (fk_aluno_id) REFERENCES tb_alunos (pk_rgm),
    CONSTRAINT uq_email_aluno    UNIQUE (email),
    CONSTRAINT chk_tipo_email_a  CHECK (tipo IN ('Pessoal', 'Recados', 'Comercial'))
);

-- -----------------------------------------------------------------------------
-- tb_telefones_alunos
-- [C2] atributo multivalorado -- 1FN corrigida
-- -----------------------------------------------------------------------------
CREATE TABLE tb_telefones_alunos (
    pk_id_telefone  INT         NOT NULL AUTO_INCREMENT,
    fk_aluno_id     INT         NOT NULL,
    numero          VARCHAR(15) NOT NULL,
    tipo            VARCHAR(20) NOT NULL DEFAULT 'Celular',

    CONSTRAINT pk_telefones_alunos  PRIMARY KEY (pk_id_telefone),
    CONSTRAINT fk_tel_aluno         FOREIGN KEY (fk_aluno_id) REFERENCES tb_alunos (pk_rgm),
    CONSTRAINT chk_tipo_tel_a       CHECK (tipo IN ('Celular', 'Residencial', 'Comercial'))
);

-- -----------------------------------------------------------------------------
-- tb_disciplinas
-- Desacoplada de cursos -- vinculo feito por tb_curso_disciplina (N:N)
-- -----------------------------------------------------------------------------
CREATE TABLE tb_disciplinas (
    pk_id_disciplina  INT          NOT NULL AUTO_INCREMENT,
    nome_disciplina   VARCHAR(100) NOT NULL,
    carga_horaria     INT          NOT NULL,
    ementa            TEXT,

    CONSTRAINT pk_disciplinas PRIMARY KEY (pk_id_disciplina),
    CONSTRAINT chk_carga_disc CHECK (carga_horaria > 0)
);

-- -----------------------------------------------------------------------------
-- tb_curso_disciplina -- N:N (cursos x disciplinas)
-- [C8] resolve multivalorado: uma disciplina pode estar em varios cursos
-- [C5] PK composta fisica
-- -----------------------------------------------------------------------------
CREATE TABLE tb_curso_disciplina (
    fk_curso_id       INT NOT NULL,
    fk_disciplina_id  INT NOT NULL,
    semestre          INT NOT NULL,
    creditos          INT NOT NULL,

    CONSTRAINT pk_curso_disciplina PRIMARY KEY (fk_curso_id, fk_disciplina_id),
    CONSTRAINT fk_cd_curso         FOREIGN KEY (fk_curso_id) REFERENCES tb_cursos (pk_id_curso),
    CONSTRAINT fk_cd_disciplina    FOREIGN KEY (fk_disciplina_id) REFERENCES tb_disciplinas (pk_id_disciplina),
    CONSTRAINT chk_semestre_cd     CHECK (semestre > 0),
    CONSTRAINT chk_creditos_cd     CHECK (creditos > 0)
);

-- -----------------------------------------------------------------------------
-- tb_turmas
-- [C4] vagas_ocupadas removida -- calculada em vw_ocupacao_turmas
-- -----------------------------------------------------------------------------
CREATE TABLE tb_turmas (
    pk_id_turma      INT         NOT NULL AUTO_INCREMENT,
    codigo_turma     VARCHAR(20) NOT NULL,
    nome_curso       VARCHAR(100) NOT NULL,
    ano              INT         NOT NULL,
    semestre_letivo  INT         NOT NULL,
    vagas            INT         NOT NULL,

    CONSTRAINT pk_turmas           PRIMARY KEY (pk_id_turma),
    CONSTRAINT uq_codigo_turma     UNIQUE (codigo_turma),
    CONSTRAINT chk_semestre_letivo CHECK (semestre_letivo IN (1, 2)),
    CONSTRAINT chk_vagas           CHECK (vagas > 0)
);

-- -----------------------------------------------------------------------------
-- tb_turma_disciplina -- N:N (turmas x disciplinas)
-- [C8] resolve erro apontado no feedback: turma tinha apenas 1 disciplina
-- [C5] PK composta fisica
-- [LEMBRETE DO GRUPO] Por que isso existe?
-- O professor apontou que "uma turma so pode ter uma disciplina" era erro.
-- Esta tabela resolve: uma turma pode ter varias disciplinas (ex: turma manha
-- tem BD + Algoritmos + POO ao mesmo tempo).
-- -----------------------------------------------------------------------------
CREATE TABLE tb_turma_disciplina (
    fk_turma_id       INT NOT NULL,
    fk_disciplina_id  INT NOT NULL,

    CONSTRAINT pk_turma_disciplina PRIMARY KEY (fk_turma_id, fk_disciplina_id),
    CONSTRAINT fk_td_turma         FOREIGN KEY (fk_turma_id) REFERENCES tb_turmas (pk_id_turma),
    CONSTRAINT fk_td_disciplina    FOREIGN KEY (fk_disciplina_id) REFERENCES tb_disciplinas (pk_id_disciplina)
);

-- -----------------------------------------------------------------------------
-- tb_grade_horaria
-- -----------------------------------------------------------------------------
CREATE TABLE tb_grade_horaria (
    pk_id_grade       INT         NOT NULL AUTO_INCREMENT,
    fk_turma_id       INT         NOT NULL,
    fk_disciplina_id  INT         NOT NULL,
    dia_semana        VARCHAR(15) NOT NULL,
    horario_inicio    TIME        NOT NULL,
    horario_fim       TIME        NOT NULL,
    sala              VARCHAR(20) NOT NULL,

    CONSTRAINT pk_grade_horaria PRIMARY KEY (pk_id_grade),
    CONSTRAINT fk_grade_turma   FOREIGN KEY (fk_turma_id) REFERENCES tb_turmas (pk_id_turma),
    CONSTRAINT fk_grade_disc    FOREIGN KEY (fk_disciplina_id) REFERENCES tb_disciplinas (pk_id_disciplina),
    CONSTRAINT chk_dia_semana   CHECK (dia_semana IN ('Segunda','Terca','Quarta','Quinta','Sexta','Sabado')),
    CONSTRAINT chk_horario      CHECK (horario_fim > horario_inicio)
);

-- -----------------------------------------------------------------------------
-- tb_matriculas -- ENTIDADE ASSOCIATIVA N:N (alunos x turmas)
-- [C5] PK composta fisica (sem AUTO_INCREMENT artificial)
-- [LEMBRETE DO GRUPO] Por que PK composta aqui?
-- O feedback apontou que usamos ID artificial como PK em entidade associativa.
-- A correcao: a combinacao (aluno + turma) JA E unica e suficiente como PK.
-- Um aluno nao pode se matricular duas vezes na mesma turma.
-- -----------------------------------------------------------------------------
CREATE TABLE tb_matriculas (
    fk_aluno_id       INT         NOT NULL,
    fk_turma_id       INT         NOT NULL,
    data_matricula    DATE        NOT NULL,
    status_matricula  VARCHAR(20) NOT NULL DEFAULT 'Ativa',
    criado_em         TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_matriculas        PRIMARY KEY (fk_aluno_id, fk_turma_id),
    CONSTRAINT fk_mat_aluno         FOREIGN KEY (fk_aluno_id) REFERENCES tb_alunos (pk_rgm),
    CONSTRAINT fk_mat_turma         FOREIGN KEY (fk_turma_id) REFERENCES tb_turmas (pk_id_turma),
    CONSTRAINT chk_status_matricula CHECK (status_matricula IN ('Ativa','Trancada','Cancelada','Concluida'))
);

-- -----------------------------------------------------------------------------
-- tb_notas
-- [C4] nota_final removida -- calculada em vw_notas_finais
-- [C5] PK composta (uma nota por matricula)
-- [LEMBRETE DO GRUPO] Por que nota_final nao esta aqui?
-- O professor pediu que campos calculados usem VIEWs.
-- nota_final = (nota_1 + nota_2) / 2. Se guardarmos fisicamente e a formula
-- mudar, todos os dados historicos ficam inconsistentes.
-- A VIEW recalcula em tempo real sempre que consultada.
-- -----------------------------------------------------------------------------
CREATE TABLE tb_notas (
    fk_aluno_id    INT         NOT NULL,
    fk_turma_id    INT         NOT NULL,
    nota_1         DECIMAL(4,2),
    nota_2         DECIMAL(4,2),
    situacao       VARCHAR(20) NOT NULL DEFAULT 'Em Curso',
    atualizado_em  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
                                        ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_notas     PRIMARY KEY (fk_aluno_id, fk_turma_id),
    CONSTRAINT fk_nota_mat  FOREIGN KEY (fk_aluno_id, fk_turma_id)
                            REFERENCES tb_matriculas (fk_aluno_id, fk_turma_id),
    CONSTRAINT chk_nota_1   CHECK (nota_1 BETWEEN 0 AND 10),
    CONSTRAINT chk_nota_2   CHECK (nota_2 BETWEEN 0 AND 10),
    CONSTRAINT chk_situacao CHECK (situacao IN ('Aprovado','Reprovado','Em Curso','Reprovado por Falta'))
);

-- -----------------------------------------------------------------------------
-- tb_faltas
-- [C4] total_faltas removido -- calculado em vw_frequencia
-- [C5] PK composta (aluno + turma + data_aula) -- impede falta duplicada
-- -----------------------------------------------------------------------------
CREATE TABLE tb_faltas (
    fk_aluno_id  INT     NOT NULL,
    fk_turma_id  INT     NOT NULL,
    data_aula    DATE    NOT NULL,
    justificada  BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT pk_faltas    PRIMARY KEY (fk_aluno_id, fk_turma_id, data_aula),
    CONSTRAINT fk_falta_mat FOREIGN KEY (fk_aluno_id, fk_turma_id)
                            REFERENCES tb_matriculas (fk_aluno_id, fk_turma_id)
);


-- =============================================================================
-- MODULO FINANCEIRO EDUCACIONAL
-- =============================================================================

-- [LEMBRETE DO GRUPO]
-- Modulo financeiro: tudo relacionado ao contrato e pagamentos do aluno.
-- Ciclo: aluno assina contrato -> gera mensalidades -> paga (ou nao).
-- Se nao pagar: entra em tb_inadimplencia.
-- valor_total do contrato e calculado pela VIEW vw_contratos_valor.
-- multa e juros sao calculados pela VIEW vw_inadimplencia_encargos.

-- -----------------------------------------------------------------------------
-- tb_contratos
-- [C4] valor_total removido -- calculado em vw_contratos_valor
-- -----------------------------------------------------------------------------
CREATE TABLE tb_contratos (
    pk_id_contrato      INT         NOT NULL AUTO_INCREMENT,
    fk_aluno_id         INT         NOT NULL,
    fk_turma_id         INT         NOT NULL,
    data_inicio         DATE        NOT NULL,
    data_fim            DATE        NOT NULL,
    num_parcelas        INT         NOT NULL,
    status_contrato     VARCHAR(20) NOT NULL DEFAULT 'Ativo',
    criado_em           TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em       TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
                                            ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_contratos        PRIMARY KEY (pk_id_contrato),
    CONSTRAINT fk_cont_aluno       FOREIGN KEY (fk_aluno_id) REFERENCES tb_alunos (pk_rgm),
    CONSTRAINT fk_cont_turma       FOREIGN KEY (fk_turma_id) REFERENCES tb_turmas (pk_id_turma),
    CONSTRAINT chk_num_parcelas    CHECK (num_parcelas > 0),
    CONSTRAINT chk_datas_contrato  CHECK (data_fim > data_inicio),
    CONSTRAINT chk_status_contrato CHECK (status_contrato IN ('Ativo','Encerrado','Suspenso'))
);

-- -----------------------------------------------------------------------------
-- tb_valores_contrato -- historico de valores mensais
-- PK composta (contrato + vigencia): rastreia reajustes ao longo do tempo
-- -----------------------------------------------------------------------------
CREATE TABLE tb_valores_contrato (
    fk_contrato_id  INT           NOT NULL,
    vigencia        DATE          NOT NULL,
    valor_mensal    DECIMAL(10,2) NOT NULL,

    CONSTRAINT pk_valores_contrato PRIMARY KEY (fk_contrato_id, vigencia),
    CONSTRAINT fk_vc_contrato      FOREIGN KEY (fk_contrato_id) REFERENCES tb_contratos (pk_id_contrato),
    CONSTRAINT chk_valor_mensal    CHECK (valor_mensal > 0)
);

-- -----------------------------------------------------------------------------
-- tb_mensalidades
-- -----------------------------------------------------------------------------
CREATE TABLE tb_mensalidades (
    pk_id_mensalidade  INT         NOT NULL AUTO_INCREMENT,
    fk_contrato_id     INT         NOT NULL,
    num_parcela        INT         NOT NULL,
    data_vencimento    DATE        NOT NULL,
    status_pagamento   VARCHAR(20) NOT NULL DEFAULT 'Pendente',

    CONSTRAINT pk_mensalidades      PRIMARY KEY (pk_id_mensalidade),
    CONSTRAINT fk_mens_contrato     FOREIGN KEY (fk_contrato_id) REFERENCES tb_contratos (pk_id_contrato),
    CONSTRAINT uq_parcela_contrato  UNIQUE (fk_contrato_id, num_parcela),
    CONSTRAINT chk_num_parcela      CHECK (num_parcela > 0),
    CONSTRAINT chk_status_pagamento CHECK (status_pagamento IN ('Pendente','Pago','Vencido','Cancelado'))
);

-- -----------------------------------------------------------------------------
-- tb_pagamentos
-- -----------------------------------------------------------------------------
CREATE TABLE tb_pagamentos (
    pk_id_pagamento    INT           NOT NULL AUTO_INCREMENT,
    fk_mensalidade_id  INT           NOT NULL,
    data_pagamento     DATE          NOT NULL,
    valor_pago         DECIMAL(10,2) NOT NULL,
    forma_pagamento    VARCHAR(30)   NOT NULL,
    criado_em          TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_pagamentos        PRIMARY KEY (pk_id_pagamento),
    CONSTRAINT fk_pag_mensalidade   FOREIGN KEY (fk_mensalidade_id) REFERENCES tb_mensalidades (pk_id_mensalidade),
    CONSTRAINT chk_valor_pago       CHECK (valor_pago > 0),
    CONSTRAINT chk_forma_pagamento  CHECK (forma_pagamento IN ('Boleto','Cartao','PIX','Transferencia'))
);

-- -----------------------------------------------------------------------------
-- tb_inadimplencia
-- [C4] multa e juros removidos -- calculados em vw_inadimplencia_encargos
-- [LEMBRETE DO GRUPO] Por que multa e juros saem daqui?
-- Sao valores derivados: multa = valor * 2%, juros = valor * 1% ao mes.
-- Se a regra mudar (ex: multa passa a ser 3%), so muda a VIEW.
-- Se fosse coluna fisica, teriamos que recalcular e atualizar todos os registros.
-- -----------------------------------------------------------------------------
CREATE TABLE tb_inadimplencia (
    pk_id_inadimplencia  INT         NOT NULL AUTO_INCREMENT,
    fk_mensalidade_id    INT         NOT NULL,
    dias_atraso          INT         NOT NULL,
    status_negociacao    VARCHAR(30) NOT NULL DEFAULT 'Em Aberto',
    registrado_em        TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_inadimplencia       PRIMARY KEY (pk_id_inadimplencia),
    CONSTRAINT fk_inadim_mensalidade  FOREIGN KEY (fk_mensalidade_id) REFERENCES tb_mensalidades (pk_id_mensalidade),
    CONSTRAINT chk_dias_atraso        CHECK (dias_atraso >= 0),
    CONSTRAINT chk_status_negociacao  CHECK (status_negociacao IN ('Em Aberto','Negociando','Acordado','Quitado'))
);

-- -----------------------------------------------------------------------------
-- tb_contas_receber
-- -----------------------------------------------------------------------------
CREATE TABLE tb_contas_receber (
    pk_id_conta_rec  INT           NOT NULL AUTO_INCREMENT,
    fk_contrato_id   INT           NOT NULL,
    descricao        VARCHAR(200)  NOT NULL,
    valor            DECIMAL(10,2) NOT NULL,
    data_vencimento  DATE          NOT NULL,
    status_conta     VARCHAR(20)   NOT NULL DEFAULT 'Aberto',

    CONSTRAINT pk_contas_receber PRIMARY KEY (pk_id_conta_rec),
    CONSTRAINT fk_crec_contrato  FOREIGN KEY (fk_contrato_id) REFERENCES tb_contratos (pk_id_contrato),
    CONSTRAINT chk_valor_crec    CHECK (valor > 0),
    CONSTRAINT chk_status_crec   CHECK (status_conta IN ('Aberto','Recebido','Cancelado'))
);

-- -----------------------------------------------------------------------------
-- tb_contas_pagar
-- -----------------------------------------------------------------------------
CREATE TABLE tb_contas_pagar (
    pk_id_conta_pag  INT           NOT NULL AUTO_INCREMENT,
    descricao        VARCHAR(200)  NOT NULL,
    fornecedor       VARCHAR(150)  NOT NULL,
    valor            DECIMAL(10,2) NOT NULL,
    data_vencimento  DATE          NOT NULL,
    status_conta     VARCHAR(20)   NOT NULL DEFAULT 'Aberto',
    pago_em          DATE,

    CONSTRAINT pk_contas_pagar PRIMARY KEY (pk_id_conta_pag),
    CONSTRAINT chk_valor_cpag  CHECK (valor > 0),
    CONSTRAINT chk_status_cpag CHECK (status_conta IN ('Aberto','Pago','Cancelado'))
);


-- =============================================================================
-- MODULO DE RECURSOS HUMANOS
-- =============================================================================

-- [LEMBRETE DO GRUPO]
-- Modulo RH: quem trabalha na instituicao.
-- Todo professor E um funcionario (heranca 1:1).
-- tb_titulacoes_professor: correcao de 1FN -- um professor pode ter
-- Graduacao + Mestrado + Doutorado (multivalorado).
-- tb_folha_pagamento: sugerida pelo professor no feedback.

-- -----------------------------------------------------------------------------
-- tb_funcionarios
-- [C1] primeiro_nome + sobrenome
-- [C2] email em tabela propria (tb_emails_funcionarios)
-- -----------------------------------------------------------------------------
CREATE TABLE tb_funcionarios (
    pk_id_funcionario  INT           NOT NULL AUTO_INCREMENT,
    primeiro_nome      VARCHAR(60)   NOT NULL,
    sobrenome          VARCHAR(60)   NOT NULL,
    cpf                VARCHAR(11)   NOT NULL,
    nascimento         DATE          NOT NULL,
    cargo              VARCHAR(80)   NOT NULL,
    salario_base       DECIMAL(10,2) NOT NULL,
    admissao           DATE          NOT NULL,
    status_func        VARCHAR(20)   NOT NULL DEFAULT 'Ativo',
    criado_em          TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_funcionarios  PRIMARY KEY (pk_id_funcionario),
    CONSTRAINT uq_func_cpf      UNIQUE (cpf),
    CONSTRAINT chk_salario_base CHECK (salario_base > 0),
    CONSTRAINT chk_status_func  CHECK (status_func IN ('Ativo','Afastado','Desligado'))
);

-- -----------------------------------------------------------------------------
-- tb_emails_funcionarios
-- [C2] email em tabela propria (1FN)
-- -----------------------------------------------------------------------------
CREATE TABLE tb_emails_funcionarios (
    pk_id_email        INT          NOT NULL AUTO_INCREMENT,
    fk_funcionario_id  INT          NOT NULL,
    email              VARCHAR(150) NOT NULL,
    tipo               VARCHAR(20)  NOT NULL DEFAULT 'Corporativo',

    CONSTRAINT pk_emails_func   PRIMARY KEY (pk_id_email),
    CONSTRAINT fk_email_func    FOREIGN KEY (fk_funcionario_id) REFERENCES tb_funcionarios (pk_id_funcionario),
    CONSTRAINT uq_email_func    UNIQUE (email),
    CONSTRAINT chk_tipo_email_f CHECK (tipo IN ('Corporativo','Pessoal'))
);

-- -----------------------------------------------------------------------------
-- tb_professores -- especializacao de tb_funcionarios (heranca 1:1)
-- [C3] titulacao movida para tb_titulacoes_professor
-- -----------------------------------------------------------------------------
CREATE TABLE tb_professores (
    pk_fk_funcionario_id  INT          NOT NULL,
    area_atuacao          VARCHAR(100) NOT NULL,
    lattes                VARCHAR(200),
    regime_trabalho       VARCHAR(20)  NOT NULL,

    CONSTRAINT pk_professores       PRIMARY KEY (pk_fk_funcionario_id),
    CONSTRAINT fk_prof_funcionario  FOREIGN KEY (pk_fk_funcionario_id) REFERENCES tb_funcionarios (pk_id_funcionario),
    CONSTRAINT chk_regime           CHECK (regime_trabalho IN ('Integral','Parcial','Horista'))
);

-- -----------------------------------------------------------------------------
-- tb_titulacoes_professor
-- [C3] tabela propria para titulacoes -- atributo multivalorado
-- [LEMBRETE DO GRUPO] Por que isso existe?
-- O feedback apontou: "titulacao e multivalorado".
-- Um professor pode ter: Graduacao (2005) + Mestrado (2010) + Doutorado (2015).
-- Se ficasse uma coluna so, so guardariamos uma titulacao.
-- Esta tabela guarda todas, cada uma com instituicao e ano.
-- -----------------------------------------------------------------------------
CREATE TABLE tb_titulacoes_professor (
    pk_id_titulacao    INT          NOT NULL AUTO_INCREMENT,
    fk_professor_id    INT          NOT NULL,
    titulacao          VARCHAR(40)  NOT NULL,
    instituicao        VARCHAR(150),
    ano_conclusao      INT,

    CONSTRAINT pk_titulacoes     PRIMARY KEY (pk_id_titulacao),
    CONSTRAINT fk_tit_professor  FOREIGN KEY (fk_professor_id) REFERENCES tb_professores (pk_fk_funcionario_id),
    CONSTRAINT chk_titulacao     CHECK (titulacao IN ('Graduacao','Especializacao','Mestrado','Doutorado')),
    CONSTRAINT chk_ano_conclusao CHECK (ano_conclusao IS NULL OR ano_conclusao >= 1950)
);

-- -----------------------------------------------------------------------------
-- tb_folha_pagamento
-- [C7] sugerida pelo professor no feedback de RH
-- [LEMBRETE DO GRUPO] Por que adicionamos isso?
-- O professor disse: "O projeto carece de uma tabela de Folha de Pagamento."
-- Esta tabela registra bruto, descontos, INSS, IRRF e liquido de cada funcionario
-- por mes. Essencial para um ERP real de compliance trabalhista.
-- -----------------------------------------------------------------------------
CREATE TABLE tb_folha_pagamento (
    pk_id_folha        INT           NOT NULL AUTO_INCREMENT,
    fk_funcionario_id  INT           NOT NULL,
    mes_referencia     INT           NOT NULL,
    ano_referencia     INT           NOT NULL,
    horas_trabalhadas  INT,
    bruto              DECIMAL(10,2) NOT NULL,
    descontos          DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    inss               DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    irrf               DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    liquido            DECIMAL(10,2) NOT NULL,
    pago_em            DATE,
    status_folha       VARCHAR(20)   NOT NULL DEFAULT 'Processando',

    CONSTRAINT pk_folha_pagamento PRIMARY KEY (pk_id_folha),
    CONSTRAINT fk_folha_func      FOREIGN KEY (fk_funcionario_id) REFERENCES tb_funcionarios (pk_id_funcionario),
    CONSTRAINT uq_folha_mes_ano   UNIQUE (fk_funcionario_id, mes_referencia, ano_referencia),
    CONSTRAINT chk_mes_folha      CHECK (mes_referencia BETWEEN 1 AND 12),
    CONSTRAINT chk_ano_folha      CHECK (ano_referencia >= 2020),
    CONSTRAINT chk_status_folha   CHECK (status_folha IN ('Processando','Pago','Cancelado'))
);

-- -----------------------------------------------------------------------------
-- tb_vinculos -- ENTIDADE ASSOCIATIVA N:N (professores x turmas)
-- [C5] PK composta fisica (professor + turma + data_inicio)
-- permite historico: mesmo professor pode voltar para turma em outro periodo
-- -----------------------------------------------------------------------------
CREATE TABLE tb_vinculos (
    fk_professor_id  INT     NOT NULL,
    fk_turma_id      INT     NOT NULL,
    data_inicio      DATE    NOT NULL,
    data_fim         DATE,
    ativo            BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_vinculos       PRIMARY KEY (fk_professor_id, fk_turma_id, data_inicio),
    CONSTRAINT fk_vinc_professor FOREIGN KEY (fk_professor_id) REFERENCES tb_professores (pk_fk_funcionario_id),
    CONSTRAINT fk_vinc_turma     FOREIGN KEY (fk_turma_id) REFERENCES tb_turmas (pk_id_turma),
    CONSTRAINT chk_datas_vinculo CHECK (data_fim IS NULL OR data_fim >= data_inicio)
);

-- -----------------------------------------------------------------------------
-- tb_carga_horaria
-- -----------------------------------------------------------------------------
CREATE TABLE tb_carga_horaria (
    pk_id_carga      INT  NOT NULL AUTO_INCREMENT,
    fk_professor_id  INT  NOT NULL,
    fk_turma_id      INT  NOT NULL,
    horas_semanais   INT  NOT NULL,
    mes_referencia   INT  NOT NULL,
    ano_referencia   INT  NOT NULL,

    CONSTRAINT pk_carga_horaria PRIMARY KEY (pk_id_carga),
    CONSTRAINT fk_carga_prof    FOREIGN KEY (fk_professor_id) REFERENCES tb_professores (pk_fk_funcionario_id),
    CONSTRAINT fk_carga_turma   FOREIGN KEY (fk_turma_id) REFERENCES tb_turmas (pk_id_turma),
    CONSTRAINT uq_carga_mes_ano UNIQUE (fk_professor_id, fk_turma_id, mes_referencia, ano_referencia),
    CONSTRAINT chk_horas        CHECK (horas_semanais > 0),
    CONSTRAINT chk_mes_carga    CHECK (mes_referencia BETWEEN 1 AND 12),
    CONSTRAINT chk_ano_carga    CHECK (ano_referencia >= 2020)
);


-- =============================================================================
-- VIEWS PARA CAMPOS CALCULADOS (3FN)
-- [C4] Substituem todos os campos derivados removidos das tabelas
-- =============================================================================
--
-- [LEMBRETE DO GRUPO]
-- VIEWs nao guardam dados -- recalculam toda vez que sao consultadas.
-- O professor pediu isso porque campos calculados violam a 3FN.
-- Se a formula mudar, so muda a VIEW. Os dados originais ficam intactos.
-- Exemplo: "Por que nota_final nao esta na tabela?"
-- Porque nota_final = (nota_1 + nota_2) / 2 e derivado das outras duas.
-- Se guardarmos fisicamente, temos que garantir sempre que os tres
-- estao sincronizados -- o que e difragil e propenso a bugs.

-- -----------------------------------------------------------------------------
-- vw_notas_finais -- substitui campo fisico nota_final
-- -----------------------------------------------------------------------------
CREATE VIEW vw_notas_finais AS
SELECT
    n.fk_aluno_id,
    n.fk_turma_id,
    CONCAT(a.primeiro_nome, ' ', a.sobrenome) AS nome_aluno,
    t.nome_curso,
    n.nota_1,
    n.nota_2,
    ROUND((n.nota_1 + n.nota_2) / 2, 2)      AS nota_final_calculada,
    n.situacao,
    n.atualizado_em
FROM tb_notas n
JOIN tb_alunos a ON n.fk_aluno_id = a.pk_rgm
JOIN tb_turmas t ON n.fk_turma_id = t.pk_id_turma;

-- -----------------------------------------------------------------------------
-- vw_frequencia -- substitui campo fisico total_faltas
-- -----------------------------------------------------------------------------
CREATE VIEW vw_frequencia AS
SELECT
    f.fk_aluno_id,
    f.fk_turma_id,
    COUNT(*)                                              AS total_faltas,
    SUM(CASE WHEN f.justificada = TRUE  THEN 1 ELSE 0 END) AS faltas_justificadas,
    SUM(CASE WHEN f.justificada = FALSE THEN 1 ELSE 0 END) AS faltas_injustificadas,
    d.carga_horaria,
    ROUND(COUNT(*) * 100.0 / d.carga_horaria, 1)         AS percentual_faltas,
    CASE
        WHEN COUNT(*) * 100.0 / d.carga_horaria > 25
        THEN 'Reprovado por Falta'
        ELSE 'Dentro do Limite'
    END AS status_frequencia
FROM tb_faltas f
JOIN tb_matriculas m        ON f.fk_aluno_id = m.fk_aluno_id AND f.fk_turma_id = m.fk_turma_id
JOIN tb_turma_disciplina td ON m.fk_turma_id = td.fk_turma_id
JOIN tb_disciplinas d       ON td.fk_disciplina_id = d.pk_id_disciplina
GROUP BY f.fk_aluno_id, f.fk_turma_id, d.carga_horaria;

-- -----------------------------------------------------------------------------
-- vw_ocupacao_turmas -- substitui campo fisico vagas_ocupadas
-- -----------------------------------------------------------------------------
CREATE VIEW vw_ocupacao_turmas AS
SELECT
    t.pk_id_turma,
    t.codigo_turma,
    t.vagas,
    COUNT(m.fk_aluno_id)            AS vagas_ocupadas,
    t.vagas - COUNT(m.fk_aluno_id)  AS vagas_disponiveis
FROM tb_turmas t
LEFT JOIN tb_matriculas m ON t.pk_id_turma = m.fk_turma_id
                         AND m.status_matricula = 'Ativa'
GROUP BY t.pk_id_turma, t.codigo_turma, t.vagas;

-- -----------------------------------------------------------------------------
-- vw_contratos_valor -- substitui campo fisico valor_total
-- -----------------------------------------------------------------------------
CREATE VIEW vw_contratos_valor AS
SELECT
    c.pk_id_contrato,
    c.fk_aluno_id,
    c.fk_turma_id,
    c.num_parcelas,
    c.status_contrato,
    COALESCE(SUM(vc.valor_mensal), 0) AS valor_total_calculado
FROM tb_contratos c
LEFT JOIN tb_valores_contrato vc ON c.pk_id_contrato = vc.fk_contrato_id
GROUP BY c.pk_id_contrato, c.fk_aluno_id, c.fk_turma_id, c.num_parcelas, c.status_contrato;

-- -----------------------------------------------------------------------------
-- vw_inadimplencia_encargos -- substitui campos fisicos multa e juros
-- Regras: multa = 2% sobre o valor, juros = 1% ao mes
-- -----------------------------------------------------------------------------
CREATE VIEW vw_inadimplencia_encargos AS
SELECT
    i.pk_id_inadimplencia,
    i.fk_mensalidade_id,
    CONCAT(a.primeiro_nome, ' ', a.sobrenome)              AS nome_aluno,
    m.data_vencimento,
    vc.valor_mensal                                        AS valor_original,
    i.dias_atraso,
    ROUND(vc.valor_mensal * 0.02, 2)                       AS multa_2pct,
    ROUND(vc.valor_mensal * 0.01 * (i.dias_atraso / 30.0), 2) AS juros_1pct_am,
    ROUND(vc.valor_mensal + vc.valor_mensal * 0.02
          + vc.valor_mensal * 0.01 * (i.dias_atraso / 30.0), 2) AS total_devido,
    i.status_negociacao
FROM tb_inadimplencia i
JOIN tb_mensalidades m      ON i.fk_mensalidade_id = m.pk_id_mensalidade
JOIN tb_contratos c         ON m.fk_contrato_id    = c.pk_id_contrato
JOIN tb_alunos a            ON c.fk_aluno_id        = a.pk_rgm
JOIN tb_valores_contrato vc ON c.pk_id_contrato     = vc.fk_contrato_id
    AND vc.vigencia = (
        SELECT MAX(v2.vigencia) FROM tb_valores_contrato v2
        WHERE v2.fk_contrato_id = c.pk_id_contrato
          AND v2.vigencia <= m.data_vencimento
    );

-- -----------------------------------------------------------------------------
-- vw_faturamento_mensal -- relatorio financeiro mensal
-- -----------------------------------------------------------------------------
CREATE VIEW vw_faturamento_mensal AS
SELECT
    YEAR(p.data_pagamento)                AS ano,
    MONTH(p.data_pagamento)               AS mes,
    COUNT(*)                              AS total_pagamentos,
    SUM(p.valor_pago)                     AS faturamento_realizado
FROM tb_pagamentos p
GROUP BY YEAR(p.data_pagamento), MONTH(p.data_pagamento)
ORDER BY ano DESC, mes ASC;

-- -----------------------------------------------------------------------------
-- vw_desempenho_aluno -- visao de BI consolidada por aluno
-- -----------------------------------------------------------------------------
CREATE VIEW vw_desempenho_aluno AS
SELECT
    a.pk_rgm,
    CONCAT(a.primeiro_nome, ' ', a.sobrenome) AS nome_completo,
    a.status_aluno,
    COUNT(DISTINCT m.fk_turma_id)             AS turmas_ativas,
    ROUND(AVG((n.nota_1 + n.nota_2) / 2), 2) AS media_geral,
    COUNT(DISTINCT f.data_aula)               AS total_faltas,
    COUNT(DISTINCT i.pk_id_inadimplencia)     AS mensalidades_inadimplentes
FROM tb_alunos a
LEFT JOIN tb_matriculas m    ON a.pk_rgm = m.fk_aluno_id AND m.status_matricula = 'Ativa'
LEFT JOIN tb_notas n         ON m.fk_aluno_id = n.fk_aluno_id AND m.fk_turma_id = n.fk_turma_id
LEFT JOIN tb_faltas f        ON m.fk_aluno_id = f.fk_aluno_id AND m.fk_turma_id = f.fk_turma_id
LEFT JOIN tb_contratos c     ON a.pk_rgm = c.fk_aluno_id
LEFT JOIN tb_mensalidades ms ON c.pk_id_contrato = ms.fk_contrato_id
LEFT JOIN tb_inadimplencia i ON ms.pk_id_mensalidade = i.fk_mensalidade_id
GROUP BY a.pk_rgm, a.primeiro_nome, a.sobrenome, a.status_aluno;

SHOW TABLES;
SELECT 'DDL concluido -- estrutura criada com sucesso' AS status;


-- =============================================================================
-- PARTE 2 -- DML: CARGA DE DADOS (IDEMPOTENTE)
-- =============================================================================
--
-- [LEMBRETE DO GRUPO]
-- INSERT IGNORE: se o registro ja existe (mesma PK ou UNIQUE), ele pula.
-- Nao da erro, nao duplica. Isso e idempotencia.
-- A banca vai rodar o script duas vezes. Os COUNT(*) devem ser identicos.
-- Exemplo para explicar: "Se eu inserir o aluno com pk_rgm=1 duas vezes,
-- o segundo INSERT IGNORE e simplesmente ignorado."

INSERT IGNORE INTO tb_turmas (pk_id_turma, codigo_turma, nome_curso, ano, semestre_letivo, vagas) VALUES
    (1, 'ESW-2024-1', 'Engenharia de Software',  2024, 1, 40),
    (2, 'CC-2024-1',  'Ciencia da Computacao',   2024, 1, 40),
    (3, 'SI-2024-1',  'Sistemas de Informacao',  2024, 1, 35),
    (4, 'IA-2024-1',  'Inteligencia Artificial', 2024, 1, 30);

INSERT IGNORE INTO tb_alunos (pk_rgm, primeiro_nome, sobrenome, nascimento, cpf, status_aluno) VALUES
    (1, 'Maria',   'Silva',     '2001-03-15', '11122233344', 'Ativo'),
    (2, 'Joao',    'Santos',    '2000-07-22', '22233344455', 'Ativo'),
    (3, 'Pedro',   'Costa',     '2002-01-10', '33344455566', 'Ativo'),
    (4, 'Lucas',   'Ferreira',  '1999-11-05', '44455566677', 'Ativo'),
    (5, 'Camila',  'Oliveira',  '2001-06-30', '55566677788', 'Ativo'),
    (6, 'Rafael',  'Mendes',    '2003-04-18', '66677788899', 'Trancado');

INSERT IGNORE INTO tb_emails_alunos (pk_id_email, fk_aluno_id, email, tipo) VALUES
    (1, 1, 'maria.silva@unicid.edu.br',    'Pessoal'),
    (2, 2, 'joao.santos@unicid.edu.br',    'Pessoal'),
    (3, 3, 'pedro.costa@unicid.edu.br',    'Pessoal'),
    (4, 4, 'lucas.ferreira@unicid.edu.br', 'Pessoal'),
    (5, 5, 'camila.oliveira@unicid.edu.br','Pessoal'),
    (6, 6, 'rafael.mendes@unicid.edu.br',  'Pessoal');

INSERT IGNORE INTO tb_telefones_alunos (pk_id_telefone, fk_aluno_id, numero, tipo) VALUES
    (1, 1, '11911112222', 'Celular'),
    (2, 2, '11922223333', 'Celular'),
    (3, 3, '11933334444', 'Celular'),
    (4, 4, '11944445555', 'Celular'),
    (5, 5, '11955556666', 'Celular'),
    (6, 6, '11966667777', 'Celular');

INSERT IGNORE INTO tb_disciplinas (pk_id_disciplina, nome_disciplina, carga_horaria) VALUES
    (1, 'Banco de Dados I',         80),
    (2, 'Banco de Dados II',        80),
    (3, 'Algoritmos e Estruturas',  80),
    (4, 'Engenharia de Software',   60),
    (5, 'Inteligencia Artificial',  80);

INSERT IGNORE INTO tb_turma_disciplina (fk_turma_id, fk_disciplina_id) VALUES
    (1, 1), (2, 2), (3, 3), (4, 5), (1, 4);

INSERT IGNORE INTO tb_matriculas (fk_aluno_id, fk_turma_id, data_matricula, status_matricula) VALUES
    (1, 1, '2024-02-01', 'Ativa'),
    (1, 2, '2024-02-01', 'Ativa'),
    (2, 1, '2024-02-01', 'Ativa'),
    (3, 2, '2024-02-01', 'Ativa'),
    (4, 3, '2024-02-01', 'Ativa'),
    (5, 1, '2024-02-01', 'Ativa'),
    (6, 2, '2024-02-01', 'Trancada');

INSERT IGNORE INTO tb_notas (fk_aluno_id, fk_turma_id, nota_1, nota_2, situacao) VALUES
    (1, 1, 8.5,  9.0,  'Aprovado'),
    (1, 2, 7.5,  8.0,  'Aprovado'),
    (2, 1, 6.0,  5.5,  'Aprovado'),
    (3, 2, 9.5,  9.8,  'Aprovado'),
    (4, 3, 4.0,  3.5,  'Reprovado'),
    (5, 1, 7.0,  8.0,  'Aprovado'),
    (6, 2, NULL, NULL, 'Em Curso');

INSERT IGNORE INTO tb_faltas (fk_aluno_id, fk_turma_id, data_aula, justificada) VALUES
    (2, 1, '2024-03-04', FALSE),
    (2, 1, '2024-03-11', FALSE),
    (4, 3, '2024-03-04', FALSE),
    (4, 3, '2024-03-11', FALSE),
    (4, 3, '2024-03-18', FALSE),
    (5, 1, '2024-03-04', TRUE);

INSERT IGNORE INTO tb_funcionarios
    (pk_id_funcionario, primeiro_nome, sobrenome, cpf, nascimento, cargo, salario_base, admissao)
VALUES
    (1, 'Carlos',  'Drummond', '12312312300', '1975-05-10', 'Professor', 8500.00, '2015-02-01'),
    (2, 'Mariana', 'Pereira',  '23423423400', '1980-08-22', 'Professor', 9200.00, '2012-07-15'),
    (3, 'Roberto', 'Farias',   '34534534500', '1978-03-15', 'Professor', 7800.00, '2018-01-10'),
    (4, 'Renato',  'Moura',    '45645645600', '1990-06-20', 'Coord.',    6500.00, '2020-08-01');

INSERT IGNORE INTO tb_emails_funcionarios (pk_id_email, fk_funcionario_id, email, tipo) VALUES
    (1, 1, 'carlos.drummond@unicid.edu.br', 'Corporativo'),
    (2, 2, 'mariana.pereira@unicid.edu.br', 'Corporativo'),
    (3, 3, 'roberto.farias@unicid.edu.br',  'Corporativo'),
    (4, 4, 'renato.moura@unicid.edu.br',    'Corporativo');

INSERT IGNORE INTO tb_professores
    (pk_fk_funcionario_id, area_atuacao, lattes, regime_trabalho) VALUES
    (1, 'Banco de Dados e BI',     'http://lattes.cnpq.br/111', 'Integral'),
    (2, 'Inteligencia Artificial', 'http://lattes.cnpq.br/222', 'Integral'),
    (3, 'Engenharia de Software',  'http://lattes.cnpq.br/333', 'Parcial');

INSERT IGNORE INTO tb_titulacoes_professor
    (pk_id_titulacao, fk_professor_id, titulacao, instituicao, ano_conclusao) VALUES
    (1, 1, 'Doutorado',      'USP',     2008),
    (2, 1, 'Mestrado',       'USP',     2003),
    (3, 2, 'Doutorado',      'UNICAMP', 2010),
    (4, 3, 'Mestrado',       'UNESP',   2012),
    (5, 3, 'Especializacao', 'PUC-SP',  2009);

INSERT IGNORE INTO tb_vinculos
    (fk_professor_id, fk_turma_id, data_inicio, data_fim, ativo) VALUES
    (1, 1, '2024-02-01', NULL, TRUE),
    (1, 2, '2024-02-01', NULL, TRUE),
    (2, 4, '2024-02-01', NULL, TRUE),
    (3, 3, '2024-02-01', NULL, TRUE);

INSERT IGNORE INTO tb_carga_horaria
    (pk_id_carga, fk_professor_id, fk_turma_id, horas_semanais, mes_referencia, ano_referencia) VALUES
    (1, 1, 1, 6, 2, 2024), (2, 1, 2, 6, 2, 2024),
    (3, 2, 4, 6, 2, 2024), (4, 3, 3, 4, 2, 2024);

INSERT IGNORE INTO tb_folha_pagamento
    (pk_id_folha, fk_funcionario_id, mes_referencia, ano_referencia,
     horas_trabalhadas, bruto, descontos, inss, irrf, liquido, pago_em, status_folha) VALUES
    (1, 1, 2, 2024, 160, 8500.00, 200.00, 935.00, 1092.00, 6273.00, '2024-02-29', 'Pago'),
    (2, 2, 2, 2024, 160, 9200.00, 200.00,1012.00, 1298.00, 6690.00, '2024-02-29', 'Pago'),
    (3, 3, 2, 2024,  80, 3900.00, 100.00, 429.00,  167.00, 3204.00, '2024-02-29', 'Pago'),
    (4, 4, 2, 2024, 160, 6500.00, 150.00, 715.00,  700.00, 4935.00, '2024-02-29', 'Pago');

INSERT IGNORE INTO tb_contratos
    (pk_id_contrato, fk_aluno_id, fk_turma_id, data_inicio, data_fim, num_parcelas, status_contrato) VALUES
    (1, 1, 1, '2024-02-01', '2028-12-31', 10, 'Ativo'),
    (2, 2, 1, '2024-02-01', '2028-12-31', 10, 'Ativo'),
    (3, 3, 2, '2024-02-01', '2028-12-31', 10, 'Ativo'),
    (4, 4, 3, '2024-02-01', '2028-12-31', 10, 'Suspenso'),
    (5, 5, 1, '2024-02-01', '2028-12-31', 10, 'Ativo');

INSERT IGNORE INTO tb_valores_contrato (fk_contrato_id, vigencia, valor_mensal) VALUES
    (1, '2024-02-01', 950.00), (2, '2024-02-01', 950.00),
    (3, '2024-02-01', 950.00), (4, '2024-02-01', 950.00),
    (5, '2024-02-01', 950.00);

INSERT IGNORE INTO tb_mensalidades
    (pk_id_mensalidade, fk_contrato_id, num_parcela, data_vencimento, status_pagamento) VALUES
    (1,  1, 1, '2024-03-10', 'Pago'),    (2,  1, 2, '2024-04-10', 'Pago'),
    (3,  1, 3, '2024-05-10', 'Pendente'),(4,  2, 1, '2024-03-10', 'Pago'),
    (5,  2, 2, '2024-04-10', 'Vencido'), (6,  2, 3, '2024-05-10', 'Vencido'),
    (7,  3, 1, '2024-03-10', 'Pago'),    (8,  3, 2, '2024-04-10', 'Pago'),
    (9,  4, 1, '2024-03-10', 'Pago'),    (10, 4, 2, '2024-04-10', 'Vencido'),
    (11, 5, 1, '2024-03-10', 'Pago'),    (12, 5, 2, '2024-04-10', 'Pago');

INSERT IGNORE INTO tb_pagamentos
    (pk_id_pagamento, fk_mensalidade_id, data_pagamento, valor_pago, forma_pagamento) VALUES
    (1,  1,  '2024-03-05', 950.00, 'PIX'),
    (2,  2,  '2024-04-08', 950.00, 'PIX'),
    (3,  4,  '2024-03-08', 950.00, 'Boleto'),
    (4,  7,  '2024-03-07', 950.00, 'Cartao'),
    (5,  8,  '2024-04-09', 950.00, 'Cartao'),
    (6,  9,  '2024-03-06', 950.00, 'Transferencia'),
    (7,  11, '2024-03-05', 950.00, 'PIX'),
    (8,  12, '2024-04-07', 950.00, 'PIX');

INSERT IGNORE INTO tb_inadimplencia
    (pk_id_inadimplencia, fk_mensalidade_id, dias_atraso, status_negociacao) VALUES
    (1, 5,  25, 'Em Aberto'),
    (2, 6,  10, 'Em Aberto'),
    (3, 10, 25, 'Negociando');

SELECT 'Carga DML concluida' AS status;


-- =============================================================================
-- PARTE 3 -- VALIDACAO DE IDEMPOTENCIA
-- =============================================================================
--
-- [LEMBRETE DO GRUPO]
-- A banca vai rodar o script duas vezes seguidas.
-- Mostre este SELECT antes e depois. Os numeros tem que ser IDENTICOS.
-- Se mudar: os INSERTs nao estao idempotentes e voce perde 20 pontos.
-- INSERT IGNORE garante isso.

SELECT 'VALIDACAO DE IDEMPOTENCIA -- rode 2x e compare' AS instrucao;
SELECT 'tb_alunos'        AS tabela, COUNT(*) AS total FROM tb_alunos        UNION ALL
SELECT 'tb_turmas',                  COUNT(*)           FROM tb_turmas        UNION ALL
SELECT 'tb_matriculas',              COUNT(*)           FROM tb_matriculas     UNION ALL
SELECT 'tb_notas',                   COUNT(*)           FROM tb_notas          UNION ALL
SELECT 'tb_faltas',                  COUNT(*)           FROM tb_faltas         UNION ALL
SELECT 'tb_contratos',               COUNT(*)           FROM tb_contratos      UNION ALL
SELECT 'tb_mensalidades',            COUNT(*)           FROM tb_mensalidades   UNION ALL
SELECT 'tb_pagamentos',              COUNT(*)           FROM tb_pagamentos     UNION ALL
SELECT 'tb_inadimplencia',           COUNT(*)           FROM tb_inadimplencia  UNION ALL
SELECT 'tb_funcionarios',            COUNT(*)           FROM tb_funcionarios   UNION ALL
SELECT 'tb_professores',             COUNT(*)           FROM tb_professores    UNION ALL
SELECT 'tb_folha_pagamento',         COUNT(*)           FROM tb_folha_pagamento;


-- =============================================================================
-- PARTE 4 -- OPERACOES OLTP
-- =============================================================================
--
-- [LEMBRETE DO GRUPO]
-- OLTP = operacoes do dia a dia. Nao e analise, e acao.
-- SELECT simples: busca direta. Subselect: uma pergunta dentro da outra.
-- SUM/AVG: agregar numeros. ROLLBACK: desfaz. COMMIT: confirma para sempre.

-- Alunos ativos
SELECT pk_rgm,
       CONCAT(primeiro_nome, ' ', sobrenome) AS nome_completo,
       status_aluno
FROM tb_alunos
WHERE status_aluno = 'Ativo'
ORDER BY sobrenome;

-- Notas finais calculadas (via VIEW -- campo fisico nao existe mais)
SELECT nome_aluno, nome_curso, nota_1, nota_2, nota_final_calculada, situacao
FROM vw_notas_finais
ORDER BY nota_final_calculada DESC;

-- SUM e AVG de notas por aluno (item do quadro: "notas SUM aluno")
SELECT CONCAT(a.primeiro_nome, ' ', a.sobrenome) AS aluno,
       COUNT(n.fk_turma_id)                       AS disciplinas,
       SUM(n.nota_1)                               AS soma_notas_1,
       ROUND(AVG((n.nota_1 + n.nota_2) / 2), 2)  AS media_geral
FROM tb_alunos a
JOIN tb_notas n ON a.pk_rgm = n.fk_aluno_id
WHERE n.nota_1 IS NOT NULL
GROUP BY a.pk_rgm, a.primeiro_nome, a.sobrenome
ORDER BY media_geral DESC;

-- Subselect: alunos com media acima de 7.0
SELECT CONCAT(a.primeiro_nome, ' ', a.sobrenome) AS aluno
FROM tb_alunos a
WHERE a.pk_rgm IN (
    SELECT n.fk_aluno_id
    FROM tb_notas n
    WHERE n.nota_1 IS NOT NULL
    GROUP BY n.fk_aluno_id
    HAVING AVG((n.nota_1 + n.nota_2) / 2) > 7.0
)
ORDER BY a.sobrenome;

-- Subselect: alunos com mensalidade vencida
SELECT CONCAT(a.primeiro_nome, ' ', a.sobrenome) AS aluno,
       a.status_aluno
FROM tb_alunos a
WHERE EXISTS (
    SELECT 1
    FROM tb_contratos c
    JOIN tb_mensalidades m ON c.pk_id_contrato = m.fk_contrato_id
    WHERE c.fk_aluno_id = a.pk_rgm
      AND m.status_pagamento = 'Vencido'
);

-- Inadimplencia com encargos calculados (via VIEW)
SELECT nome_aluno, valor_original, dias_atraso,
       multa_2pct, juros_1pct_am, total_devido, status_negociacao
FROM vw_inadimplencia_encargos;

-- Transacao com ROLLBACK (desfaz)
START TRANSACTION;
INSERT INTO tb_pagamentos (fk_mensalidade_id, data_pagamento, valor_pago, forma_pagamento)
VALUES (5, CURDATE(), 950.00, 'PIX');
SELECT 'Dentro da transacao' AS momento, COUNT(*) AS total FROM tb_pagamentos;
ROLLBACK;
SELECT 'Apos ROLLBACK -- INSERT desfeito' AS momento, COUNT(*) AS total FROM tb_pagamentos;

-- Transacao com COMMIT (confirma)
START TRANSACTION;
UPDATE tb_mensalidades SET status_pagamento = 'Pago' WHERE pk_id_mensalidade = 5;
INSERT INTO tb_pagamentos (fk_mensalidade_id, data_pagamento, valor_pago, forma_pagamento)
VALUES (5, CURDATE(), 950.00, 'PIX');
COMMIT;
SELECT 'Apos COMMIT -- status da mensalidade 5:' AS momento,
       status_pagamento FROM tb_mensalidades WHERE pk_id_mensalidade = 5;


-- =============================================================================
-- PARTE 5 -- OLAP: MODELO ESTRELA (STAR SCHEMA)
-- =============================================================================
--
-- [LEMBRETE DO GRUPO]
-- OLAP = analise. Nao alteramos dados, so lemos e agregamos.
-- Star Schema: uma tabela FATO no centro com os numeros (metricas),
-- e DIMENSOES nas pontas com os contextos (quem, quando, onde, o que).
-- dim_aluno e dim_tempo sao "conformadas" -- compartilhadas entre
-- fato_financeiro e fato_desempenho. Isso permite analises cruzadas:
-- "alunos inadimplentes tem pior desempenho academico?"
-- Regra de ouro do professor: "Um DW possui varias tabelas fato."

-- Dimensoes
CREATE TABLE IF NOT EXISTS dim_tempo (
    sk_tempo    INT         NOT NULL AUTO_INCREMENT,
    data_ref    DATE        NOT NULL,
    dia         INT         NOT NULL,
    mes_numero  INT         NOT NULL,
    mes_nome    VARCHAR(20) NOT NULL,
    trimestre   INT         NOT NULL,
    semestre    INT         NOT NULL,
    ano         INT         NOT NULL,
    CONSTRAINT pk_dim_tempo PRIMARY KEY (sk_tempo),
    CONSTRAINT uq_dim_tempo UNIQUE (data_ref)
);

CREATE TABLE IF NOT EXISTS dim_aluno (
    sk_aluno       INT          NOT NULL AUTO_INCREMENT,
    rgm_original   INT          NOT NULL,
    nome_completo  VARCHAR(130) NOT NULL,
    status_aluno   VARCHAR(20)  NOT NULL,
    CONSTRAINT pk_dim_aluno PRIMARY KEY (sk_aluno),
    CONSTRAINT uq_dim_rgm   UNIQUE (rgm_original)
);

CREATE TABLE IF NOT EXISTS dim_curso (
    sk_curso     INT          NOT NULL AUTO_INCREMENT,
    codigo_curso VARCHAR(20)  NOT NULL,
    nome_curso   VARCHAR(100) NOT NULL,
    CONSTRAINT pk_dim_curso  PRIMARY KEY (sk_curso),
    CONSTRAINT uq_dim_codigo UNIQUE (codigo_curso)
);

CREATE TABLE IF NOT EXISTS dim_unidade (
    sk_unidade     INT          NOT NULL AUTO_INCREMENT,
    codigo_unidade VARCHAR(10)  NOT NULL,
    nome_unidade   VARCHAR(100) NOT NULL,
    cidade         VARCHAR(60),
    uf             CHAR(2),
    CONSTRAINT pk_dim_unidade PRIMARY KEY (sk_unidade)
);

CREATE TABLE IF NOT EXISTS dim_disciplina (
    sk_disciplina    INT          NOT NULL AUTO_INCREMENT,
    codigo_turma     VARCHAR(20)  NOT NULL,
    nome_curso       VARCHAR(100) NOT NULL,
    ano              INT          NOT NULL,
    semestre_letivo  INT          NOT NULL,
    CONSTRAINT pk_dim_disciplina PRIMARY KEY (sk_disciplina),
    CONSTRAINT uq_dim_disc_turma UNIQUE (codigo_turma, ano, semestre_letivo)
);

-- Tabelas fato
CREATE TABLE IF NOT EXISTS fato_financeiro (
    sk_fato                    INT           NOT NULL AUTO_INCREMENT,
    sk_aluno                   INT           NOT NULL,
    sk_tempo_vencimento        INT           NOT NULL,
    sk_curso                   INT           NOT NULL,
    sk_unidade                 INT           NOT NULL,
    id_mensalidade_origem      INT           NOT NULL,
    valor_mensalidade_contrato DECIMAL(10,2) NOT NULL,
    valor_efetivamente_pago    DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    dias_em_atraso             INT           NOT NULL DEFAULT 0,
    CONSTRAINT pk_fato_financeiro PRIMARY KEY (sk_fato),
    CONSTRAINT fk_ff_aluno        FOREIGN KEY (sk_aluno)  REFERENCES dim_aluno (sk_aluno),
    CONSTRAINT fk_ff_tempo        FOREIGN KEY (sk_tempo_vencimento) REFERENCES dim_tempo (sk_tempo),
    CONSTRAINT fk_ff_curso        FOREIGN KEY (sk_curso)  REFERENCES dim_curso (sk_curso),
    CONSTRAINT fk_ff_unidade      FOREIGN KEY (sk_unidade) REFERENCES dim_unidade (sk_unidade)
);

CREATE TABLE IF NOT EXISTS fato_desempenho (
    sk_fato_desemp  INT           NOT NULL AUTO_INCREMENT,
    sk_aluno        INT           NOT NULL,
    sk_tempo        INT           NOT NULL,
    sk_disciplina   INT           NOT NULL,
    nota_1          DECIMAL(4,2),
    nota_2          DECIMAL(4,2),
    nota_media      DECIMAL(4,2),
    total_faltas    INT           NOT NULL DEFAULT 0,
    aprovado        BOOLEAN       NOT NULL DEFAULT FALSE,
    CONSTRAINT pk_fato_desempenho PRIMARY KEY (sk_fato_desemp),
    CONSTRAINT fk_fd_aluno        FOREIGN KEY (sk_aluno)      REFERENCES dim_aluno (sk_aluno),
    CONSTRAINT fk_fd_tempo        FOREIGN KEY (sk_tempo)      REFERENCES dim_tempo (sk_tempo),
    CONSTRAINT fk_fd_disciplina   FOREIGN KEY (sk_disciplina) REFERENCES dim_disciplina (sk_disciplina)
);

-- ETL: carga das dimensoes
INSERT INTO dim_tempo (data_ref, dia, mes_numero, mes_nome, trimestre, semestre, ano)
SELECT DISTINCT m.data_vencimento,
    DAY(m.data_vencimento), MONTH(m.data_vencimento),
    CASE MONTH(m.data_vencimento)
        WHEN 1 THEN 'Janeiro'   WHEN 2 THEN 'Fevereiro' WHEN 3 THEN 'Marco'
        WHEN 4 THEN 'Abril'     WHEN 5 THEN 'Maio'      WHEN 6 THEN 'Junho'
        WHEN 7 THEN 'Julho'     WHEN 8 THEN 'Agosto'    WHEN 9 THEN 'Setembro'
        WHEN 10 THEN 'Outubro'  WHEN 11 THEN 'Novembro' WHEN 12 THEN 'Dezembro'
    END,
    CEIL(MONTH(m.data_vencimento) / 3.0),
    CASE WHEN MONTH(m.data_vencimento) <= 6 THEN 1 ELSE 2 END,
    YEAR(m.data_vencimento)
FROM tb_mensalidades m
ON DUPLICATE KEY UPDATE data_ref = VALUES(data_ref);

-- Insere tambem datas de matricula para fato_desempenho
INSERT INTO dim_tempo (data_ref, dia, mes_numero, mes_nome, trimestre, semestre, ano)
SELECT DISTINCT m.data_matricula,
    DAY(m.data_matricula), MONTH(m.data_matricula),
    CASE MONTH(m.data_matricula)
        WHEN 1 THEN 'Janeiro'   WHEN 2 THEN 'Fevereiro' WHEN 3 THEN 'Marco'
        WHEN 4 THEN 'Abril'     WHEN 5 THEN 'Maio'      WHEN 6 THEN 'Junho'
        WHEN 7 THEN 'Julho'     WHEN 8 THEN 'Agosto'    WHEN 9 THEN 'Setembro'
        WHEN 10 THEN 'Outubro'  WHEN 11 THEN 'Novembro' WHEN 12 THEN 'Dezembro'
    END,
    CEIL(MONTH(m.data_matricula) / 3.0),
    CASE WHEN MONTH(m.data_matricula) <= 6 THEN 1 ELSE 2 END,
    YEAR(m.data_matricula)
FROM tb_matriculas m
ON DUPLICATE KEY UPDATE data_ref = VALUES(data_ref);

INSERT INTO dim_aluno (rgm_original, nome_completo, status_aluno)
SELECT pk_rgm, CONCAT(primeiro_nome, ' ', sobrenome), status_aluno
FROM tb_alunos
ON DUPLICATE KEY UPDATE nome_completo = VALUES(nome_completo), status_aluno = VALUES(status_aluno);

INSERT INTO dim_curso (codigo_curso, nome_curso)
SELECT DISTINCT codigo_turma, nome_curso FROM tb_turmas
ON DUPLICATE KEY UPDATE nome_curso = VALUES(nome_curso);

INSERT INTO dim_unidade (codigo_unidade, nome_unidade, cidade, uf) VALUES
    ('MAT', 'Campus Principal - Matriz', 'Sao Paulo', 'SP'),
    ('VIL', 'Unidade Vila Mariana',       'Sao Paulo', 'SP');

INSERT INTO dim_disciplina (codigo_turma, nome_curso, ano, semestre_letivo)
SELECT DISTINCT codigo_turma, nome_curso, ano, semestre_letivo FROM tb_turmas
ON DUPLICATE KEY UPDATE nome_curso = VALUES(nome_curso);

-- ETL: carga fato_financeiro (bug de multiplicacao de linhas corrigido)
INSERT INTO fato_financeiro
    (sk_aluno, sk_tempo_vencimento, sk_curso, sk_unidade,
     id_mensalidade_origem, valor_mensalidade_contrato, valor_efetivamente_pago, dias_em_atraso)
SELECT
    da.sk_aluno, dt.sk_tempo, dc.sk_curso, 1,
    m.pk_id_mensalidade, vc.valor_mensal,
    COALESCE(pg.valor_pago, 0.00),
    COALESCE(i.dias_atraso, 0)
FROM tb_mensalidades m
JOIN tb_contratos c   ON m.fk_contrato_id = c.pk_id_contrato
JOIN tb_valores_contrato vc ON c.pk_id_contrato = vc.fk_contrato_id
    AND vc.vigencia = (
        SELECT MAX(v2.vigencia) FROM tb_valores_contrato v2
        WHERE v2.fk_contrato_id = c.pk_id_contrato AND v2.vigencia <= m.data_vencimento
    )
JOIN dim_aluno da   ON c.fk_aluno_id    = da.rgm_original
JOIN dim_tempo dt   ON m.data_vencimento = dt.data_ref
JOIN tb_turmas t    ON c.fk_turma_id    = t.pk_id_turma
JOIN dim_curso dc   ON t.codigo_turma   = dc.codigo_curso
LEFT JOIN tb_pagamentos pg ON m.pk_id_mensalidade = pg.fk_mensalidade_id
LEFT JOIN tb_inadimplencia i ON m.pk_id_mensalidade = i.fk_mensalidade_id;

-- ETL: carga fato_desempenho
INSERT INTO fato_desempenho
    (sk_aluno, sk_tempo, sk_disciplina, nota_1, nota_2, nota_media, total_faltas, aprovado)
SELECT
    da.sk_aluno, dt.sk_tempo, dd.sk_disciplina,
    n.nota_1, n.nota_2,
    ROUND((COALESCE(n.nota_1,0) + COALESCE(n.nota_2,0)) / 2, 2),
    COUNT(f.data_aula),
    CASE WHEN ((COALESCE(n.nota_1,0) + COALESCE(n.nota_2,0)) / 2) >= 5 THEN TRUE ELSE FALSE END
FROM tb_matriculas m
JOIN tb_turmas t       ON m.fk_turma_id  = t.pk_id_turma
JOIN tb_notas n        ON m.fk_aluno_id  = n.fk_aluno_id AND m.fk_turma_id = n.fk_turma_id
JOIN dim_aluno da      ON m.fk_aluno_id  = da.rgm_original
JOIN dim_disciplina dd ON t.codigo_turma = dd.codigo_turma
JOIN dim_tempo dt      ON m.data_matricula = dt.data_ref
LEFT JOIN tb_faltas f  ON m.fk_aluno_id  = f.fk_aluno_id AND m.fk_turma_id = f.fk_turma_id
GROUP BY da.sk_aluno, dt.sk_tempo, dd.sk_disciplina, n.nota_1, n.nota_2;

SELECT 'OLAP -- Star Schema carregado com sucesso' AS status;


-- =============================================================================
-- PARTE 6 -- VALIDACAO OLTP vs OLAP
-- =============================================================================
--
-- [LEMBRETE DO GRUPO]
-- Esta e a prova de que o ETL funcionou corretamente.
-- O total pago no OLTP deve ser identico ao total na fato_financeiro.
-- Se der "FALHA": o ETL tem bug (ex: multiplicou linhas por join errado).
-- Nosso script corrigiu o bug de multiplicacao que existia no codigo do grupo.

WITH validacao_oltp AS (
    SELECT ROUND(SUM(p.valor_pago), 2) AS total_OLTP FROM tb_pagamentos p
),
validacao_olap AS (
    SELECT ROUND(SUM(f.valor_efetivamente_pago), 2) AS total_OLAP FROM fato_financeiro f
)
SELECT
    v_oltp.total_OLTP,
    v_olap.total_OLAP,
    CASE
        WHEN v_oltp.total_OLTP = v_olap.total_OLAP THEN 'SUCESSO: ETL CONSISTENTE'
        ELSE CONCAT('FALHA: Diferenca de R$ ', ABS(v_oltp.total_OLTP - v_olap.total_OLAP))
    END AS resultado_validacao
FROM validacao_oltp v_oltp, validacao_olap v_olap;

-- Faturamento mensal (consulta analitica OLAP)
SELECT dt.mes_nome, dt.ano,
       COUNT(f.sk_fato)              AS mensalidades,
       SUM(f.valor_efetivamente_pago) AS faturamento
FROM fato_financeiro f
JOIN dim_tempo dt ON f.sk_tempo_vencimento = dt.sk_tempo
GROUP BY dt.ano, dt.mes_numero, dt.mes_nome
ORDER BY dt.ano DESC, dt.mes_numero ASC;

-- Media academica por curso (consulta analitica OLAP)
SELECT dd.nome_curso,
       COUNT(*)                       AS total_alunos,
       ROUND(AVG(f.nota_media), 2)   AS media_turma,
       SUM(CASE WHEN f.aprovado THEN 1 ELSE 0 END) AS aprovados
FROM fato_desempenho f
JOIN dim_disciplina dd ON f.sk_disciplina = dd.sk_disciplina
GROUP BY dd.nome_curso
ORDER BY media_turma DESC;

-- Analise cruzada: dimensao conformada dim_aluno entre fato_financeiro e fato_desempenho
SELECT
    da.nome_completo                          AS aluno,
    ROUND(AVG(fd.nota_media), 2)              AS media_academica,
    SUM(ff.valor_efetivamente_pago)           AS total_pago,
    SUM(ff.dias_em_atraso)                    AS total_dias_atraso
FROM dim_aluno da
LEFT JOIN fato_desempenho fd  ON da.sk_aluno = fd.sk_aluno
LEFT JOIN fato_financeiro ff  ON da.sk_aluno = ff.sk_aluno
GROUP BY da.sk_aluno, da.nome_completo
ORDER BY media_academica DESC;


-- =============================================================================
-- PARTE 7 -- PERFORMANCE: INDICES E EXPLAIN
-- =============================================================================
--
-- [LEMBRETE DO GRUPO]
-- Indices funcionam como o indice de um livro: em vez de ler pagina a pagina,
-- voce vai direto onde esta a informacao.
-- EXPLAIN mostra o plano do banco: quantas linhas ele vai varrer.
-- Sem indice: o banco varre todas as linhas (full table scan).
-- Com indice: vai direto nas linhas relevantes.

-- Indices OLTP
CREATE INDEX idx_mat_aluno        ON tb_matriculas   (fk_aluno_id);
CREATE INDEX idx_mat_turma        ON tb_matriculas   (fk_turma_id);
CREATE INDEX idx_notas_aluno      ON tb_notas        (fk_aluno_id, fk_turma_id);
CREATE INDEX idx_cont_aluno       ON tb_contratos    (fk_aluno_id);
CREATE INDEX idx_mens_contrato    ON tb_mensalidades (fk_contrato_id);
CREATE INDEX idx_mens_vencimento  ON tb_mensalidades (data_vencimento);
CREATE INDEX idx_mens_status      ON tb_mensalidades (status_pagamento);
CREATE INDEX idx_pag_mensalidade  ON tb_pagamentos   (fk_mensalidade_id);
CREATE INDEX idx_pag_data         ON tb_pagamentos   (data_pagamento);
CREATE INDEX idx_aluno_status     ON tb_alunos       (status_aluno);
CREATE INDEX idx_inadim_mens      ON tb_inadimplencia(fk_mensalidade_id);

-- Indices OLAP
CREATE INDEX idx_ff_aluno         ON fato_financeiro (sk_aluno);
CREATE INDEX idx_ff_tempo         ON fato_financeiro (sk_tempo_vencimento);
CREATE INDEX idx_ff_curso         ON fato_financeiro (sk_curso);
CREATE INDEX idx_ff_atraso        ON fato_financeiro (dias_em_atraso);
CREATE INDEX idx_ff_aluno_tempo   ON fato_financeiro (sk_aluno, sk_tempo_vencimento);
CREATE INDEX idx_fd_aluno         ON fato_desempenho (sk_aluno);
CREATE INDEX idx_fd_disciplina    ON fato_desempenho (sk_disciplina);

-- EXPLAIN: plano de execucao da query de faturamento mensal
EXPLAIN SELECT dt.mes_nome, dt.ano, SUM(f.valor_efetivamente_pago)
FROM fato_financeiro f
JOIN dim_tempo dt ON f.sk_tempo_vencimento = dt.sk_tempo
GROUP BY dt.ano, dt.mes_numero, dt.mes_nome;

-- EXPLAIN: plano de execucao de alunos inadimplentes (OLTP)
EXPLAIN SELECT CONCAT(a.primeiro_nome, ' ', a.sobrenome) AS aluno,
               COUNT(i.pk_id_inadimplencia) AS qtd
FROM tb_alunos a
JOIN tb_contratos c    ON a.pk_rgm             = c.fk_aluno_id
JOIN tb_mensalidades m ON c.pk_id_contrato     = m.fk_contrato_id
JOIN tb_inadimplencia i ON m.pk_id_mensalidade = i.fk_mensalidade_id
GROUP BY a.pk_rgm, a.primeiro_nome, a.sobrenome;


-- =============================================================================
-- PARTE 8 -- SCRIPT DE RESET (GOVERNANCA)
-- =============================================================================
--
-- [LEMBRETE DO GRUPO]
-- O professor pediu um script de reset na rubrica de governanca.
-- Este script limpa os DADOS mas mantem a ESTRUTURA do banco.
-- Use quando quiser recomecar os testes sem recriar as tabelas.
-- FOREIGN_KEY_CHECKS = 0 desliga verificacao de FK temporariamente
-- para o TRUNCATE funcionar em qualquer ordem.
-- Lembre de religar depois com = 1.
--
-- Para usar: descomente as linhas abaixo.

/*
SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE fato_desempenho;
TRUNCATE TABLE fato_financeiro;
TRUNCATE TABLE dim_disciplina;
TRUNCATE TABLE dim_unidade;
TRUNCATE TABLE dim_curso;
TRUNCATE TABLE dim_aluno;
TRUNCATE TABLE dim_tempo;

TRUNCATE TABLE tb_inadimplencia;
TRUNCATE TABLE tb_pagamentos;
TRUNCATE TABLE tb_mensalidades;
TRUNCATE TABLE tb_valores_contrato;
TRUNCATE TABLE tb_contratos;
TRUNCATE TABLE tb_folha_pagamento;
TRUNCATE TABLE tb_carga_horaria;
TRUNCATE TABLE tb_vinculos;
TRUNCATE TABLE tb_titulacoes_professor;
TRUNCATE TABLE tb_professores;
TRUNCATE TABLE tb_emails_funcionarios;
TRUNCATE TABLE tb_funcionarios;
TRUNCATE TABLE tb_contas_pagar;
TRUNCATE TABLE tb_contas_receber;
TRUNCATE TABLE tb_faltas;
TRUNCATE TABLE tb_notas;
TRUNCATE TABLE tb_matriculas;
TRUNCATE TABLE tb_grade_horaria;
TRUNCATE TABLE tb_turma_disciplina;
TRUNCATE TABLE tb_curso_disciplina;
TRUNCATE TABLE tb_turmas;
TRUNCATE TABLE tb_telefones_alunos;
TRUNCATE TABLE tb_emails_alunos;
TRUNCATE TABLE tb_alunos;
TRUNCATE TABLE tb_disciplinas;
TRUNCATE TABLE tb_cursos;

SET FOREIGN_KEY_CHECKS = 1;

SELECT 'Reset concluido -- banco limpo, estrutura preservada' AS status;
*/

-- =============================================================================
-- ESTATISTICAS FINAIS DO PROJETO
-- =============================================================================

SELECT 'Tabelas OLTP (tb_)'         AS metrica, COUNT(*) AS valor
FROM information_schema.tables
WHERE table_schema = 'sisgesc' AND table_name LIKE 'tb_%' AND table_type = 'BASE TABLE'
UNION ALL
SELECT 'Dimensoes OLAP (dim_)',       COUNT(*)
FROM information_schema.tables
WHERE table_schema = 'sisgesc' AND table_name LIKE 'dim_%' AND table_type = 'BASE TABLE'
UNION ALL
SELECT 'Tabelas Fato (fato_)',        COUNT(*)
FROM information_schema.tables
WHERE table_schema = 'sisgesc' AND table_name LIKE 'fato_%' AND table_type = 'BASE TABLE'
UNION ALL
SELECT 'Views analiticas',            COUNT(*)
FROM information_schema.views WHERE table_schema = 'sisgesc'
UNION ALL
SELECT 'Indices criados',             COUNT(*)
FROM information_schema.statistics
WHERE table_schema = 'sisgesc' AND index_name NOT LIKE 'PRIMARY'
UNION ALL
SELECT 'Alunos cadastrados',          COUNT(*) FROM tb_alunos
UNION ALL
SELECT 'Mensalidades geradas',        COUNT(*) FROM tb_mensalidades
UNION ALL
SELECT 'Pagamentos registrados',      COUNT(*) FROM tb_pagamentos
UNION ALL
SELECT 'Registros em fato_financeiro', COUNT(*) FROM fato_financeiro
UNION ALL
SELECT 'Registros em fato_desempenho', COUNT(*) FROM fato_desempenho;

SHOW TABLES;
SELECT 'SisGESC -- script completo executado com sucesso' AS status_final;

-- =============================================================================
-- FIM DO SCRIPT -- SisGESC run_all.sql
-- UNICID 2026 | Avaliacao Cega
-- =============================================================================
