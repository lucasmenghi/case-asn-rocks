-- Databricks notebook source
-- ABT V3: homologacao de V1 (00_engajamento.ipynb) e V2 (ABT_Metricas_Aluno.dbc).
-- SOMENTE TEMP VIEWS: execute este arquivo inteiro na mesma sessao.
-- Edite as SEIS fontes abaixo para seu catalogo.schema. Nenhuma tabela sera criada.
-- Corte historico da amostra; nao confundir com a entrega em 11/11/2026.
-- ATENCAO: as fontes sao resumos acumulados, nao um log de todos os acessos.
-- O corte calcula idades/recencia; nao reconstitui snapshots passados.
SET TIME ZONE 'UTC';

CREATE OR REPLACE TEMP VIEW v3_cfg AS
SELECT DATE '2025-11-18' AS data_inicio, DATE '2026-01-26' AS data_fim,
       10 AS tamanho_periodo, CAST(0.05 AS DOUBLE) AS percentual_minimo_assistido,
       'v3_homologacao_2026-10-25' AS versao_regra;

-- COMMAND ----------
-- 1. ADAPTADORES: alterar apenas os FROM (e nomes de colunas se necessario).
CREATE OR REPLACE TEMP VIEW v3_v2_alunos_geral AS
SELECT TRY_CAST(aluno_id AS BIGINT) aluno_id, TRY_CAST(curso_id AS BIGINT) curso_id,
       CAST(matricula_id AS STRING) matricula_id, status, titulo_curso,
       TRY_CAST(cadastro AS TIMESTAMP_NTZ) cadastro, TRY_CAST(cadastro_data AS DATE) cadastro_data
FROM case_asn.bronze.alunos_geral;

CREATE OR REPLACE TEMP VIEW v3_src_progresso AS
SELECT * FROM case_asn.bronze.progresso;

CREATE OR REPLACE TEMP VIEW v3_v2_progresso_total AS
SELECT TRY_CAST(aluno_id AS BIGINT) aluno_id, TRY_CAST(curso_id AS BIGINT) curso_id,
       TRY_CAST(modulo_id AS BIGINT) modulo_id, TRY_CAST(aula_id AS BIGINT) aula_id,
       TRY_CAST(ultima_visualizacao AS TIMESTAMP_NTZ) ultima_visualizacao,
       TRY_CAST(data_conclusao AS TIMESTAMP_NTZ) data_conclusao, tempo_aula
FROM case_asn.bronze.progresso_total;

CREATE OR REPLACE TEMP VIEW v3_v2_usuarios_geral AS
SELECT TRY_CAST(aluno_id AS BIGINT) aluno_id,
       MIN(TRY_CAST(data_cadastro AS TIMESTAMP_NTZ)) data_cadastro
FROM case_asn.bronze.usuarios_geral GROUP BY TRY_CAST(aluno_id AS BIGINT);

-- Dimensao MANUAL da V1: coluna Tempo, chave curso+modulo+aula.
CREATE OR REPLACE TEMP VIEW v3_src_duracao_manual AS
SELECT * FROM case_asn.bronze.tempo_aula;

-- Dimensao COMPLETA da V2 e dos experimentos V1: nao substituir pela manual.
-- Precisa conter duracao_segundos, duracao_hhmmss, curso, curso_id, modulo_id, aula_id.
CREATE OR REPLACE TEMP VIEW v3_v2_asn_aulas_duracao AS
SELECT TRY_CAST(curso_id AS BIGINT) curso_id, TRY_CAST(modulo_id AS BIGINT) modulo_id,
       TRY_CAST(aula_id AS BIGINT) aula_id, curso,
       TRY_CAST(duracao_segundos AS DOUBLE) duracao_segundos, duracao_hhmmss
FROM case_asn.bronze.asn_aulas_duracao;

-- COMMAND ----------
-- 2. V1: metricas, categorias, z-scores, pesos e score legado.
CREATE OR REPLACE TEMP VIEW v3_v1_cfg AS
SELECT data_fim AS data_referencia FROM v3_cfg;

-- COMMAND ----------
-- Fontes: tabelas bronze com os nomes dos arquivos, sem extensão.
CREATE OR REPLACE TEMP VIEW v3_v1_src_alunos AS
SELECT CAST(aluno_id AS STRING) AS aluno_id,
       CAST(matricula_id AS STRING) AS matricula_id,
       CAST(curso_id AS STRING) AS curso_id,
       CAST(status AS STRING) AS status,
       TRY_CAST(cadastro_data AS DATE) AS cadastro_data
FROM v3_v2_alunos_geral;

CREATE OR REPLACE TEMP VIEW v3_v1_src_progresso AS
SELECT CAST(aluno_id AS STRING) AS aluno_id,
       CAST(matricula_id AS STRING) AS matricula_id,
       CAST(curso_id AS STRING) AS curso_id,
       CAST(curso_titulo AS STRING) AS curso_titulo,
       TRY_CAST(progresso AS DOUBLE) AS progresso,
       TRY_TO_TIMESTAMP(CAST(ultimo_acesso AS STRING)) AS ultimo_acesso_ts,
       COALESCE(TRY_CAST(GET(SPLIT(CAST(carga_horaria AS STRING), ':'), 0) AS BIGINT), 0) * 3600
       + COALESCE(TRY_CAST(GET(SPLIT(CAST(carga_horaria AS STRING), ':'), 1) AS BIGINT), 0) * 60
       + COALESCE(TRY_CAST(GET(SPLIT(CAST(carga_horaria AS STRING), ':'), 2) AS BIGINT), 0) AS carga_segundos
FROM v3_src_progresso;

CREATE OR REPLACE TEMP VIEW v3_v1_src_aulas AS
SELECT CAST(aluno_id AS STRING) AS aluno_id,
       CAST(curso_id AS STRING) AS curso_id,
       CAST(modulo_id AS STRING) AS modulo_id,
       CAST(aula_id AS STRING) AS aula_id,
       CAST(TRY_TO_TIMESTAMP(CAST(ultima_visualizacao AS STRING)) AS DATE) AS data_visualizacao,
       COALESCE(TRY_CAST(GET(SPLIT(CAST(tempo_aula AS STRING), ':'), 0) AS BIGINT), 0) * 3600
       + COALESCE(TRY_CAST(GET(SPLIT(CAST(tempo_aula AS STRING), ':'), 1) AS BIGINT), 0) * 60
       + COALESCE(TRY_CAST(GET(SPLIT(CAST(tempo_aula AS STRING), ':'), 2) AS BIGINT), 0) AS tempo_segundos
FROM v3_v2_progresso_total;

-- A dimensão manual do grupo possui Tempo (case-insensitive em SQL).
-- Se sua tabela usa duracao_hhmmss, ajuste APENAS esta projeção e valide cobertura.
CREATE OR REPLACE TEMP VIEW v3_v1_src_duracao AS
SELECT CAST(curso_id AS STRING) AS curso_id,
       CAST(modulo_id AS STRING) AS modulo_id,
       CAST(aula_id AS STRING) AS aula_id,
       COALESCE(TRY_CAST(GET(SPLIT(CAST(Tempo AS STRING), ':'), 0) AS BIGINT), 0) * 3600
       + COALESCE(TRY_CAST(GET(SPLIT(CAST(Tempo AS STRING), ':'), 1) AS BIGINT), 0) * 60
       + COALESCE(TRY_CAST(GET(SPLIT(CAST(Tempo AS STRING), ':'), 2) AS BIGINT), 0) AS duracao_segundos
FROM v3_src_duracao_manual;

-- COMMAND ----------
CREATE OR REPLACE TEMP VIEW v3_v1_metricas_grupo AS
WITH frequencia AS (
    SELECT aluno_id, COUNT(DISTINCT data_visualizacao) AS Frequencia_Dias
    FROM v3_v1_src_aulas WHERE tempo_segundos >= 180 GROUP BY aluno_id
), progresso_base AS (
    SELECT p.aluno_id, p.curso_id, a.cadastro_data, p.progresso, p.carga_segundos
    FROM v3_v1_src_progresso p
    INNER JOIN v3_v1_src_alunos a ON p.matricula_id = a.matricula_id
    WHERE a.status = 'Matrícula ativa' AND p.curso_titulo <> 'Comece por aqui'
), progresso_denominador AS (
    -- MIN torna determinística a data após deduplicação aluno+curso.
    SELECT aluno_id, COUNT(DISTINCT curso_id) AS qtd_cursos_ativos,
           MIN(cadastro_data) AS cadastro_data
    FROM progresso_base GROUP BY aluno_id
), progresso_curso AS (
    SELECT aluno_id, curso_id, MAX(carga_segundos) AS carga_segundos,
           MAX(progresso) AS progresso
    FROM progresso_base GROUP BY aluno_id, curso_id
), progresso_numerador AS (
    SELECT aluno_id, SUM(progresso) AS soma_progresso
    FROM progresso_curso WHERE carga_segundos >= 600 GROUP BY aluno_id
), dm_progresso AS (
    SELECT d.aluno_id,
           (COALESCE(n.soma_progresso, 0.0) / d.qtd_cursos_ativos)
           / GREATEST(DATEDIFF(c.data_referencia, d.cadastro_data), 1) AS velocidade_progresso,
           COALESCE(n.soma_progresso,0.0) / d.qtd_cursos_ativos AS progresso_plataforma_absoluto,
           d.qtd_cursos_ativos, GREATEST(DATEDIFF(c.data_referencia,d.cadastro_data),1) AS dias_de_casa
    FROM progresso_denominador d
    LEFT JOIN progresso_numerador n ON d.aluno_id = n.aluno_id
    CROSS JOIN v3_v1_cfg c
), profundidade AS (
    SELECT aluno_id, SUM(tempo_segundos) AS profundidade_total_segundos
    FROM v3_v1_src_aulas GROUP BY aluno_id
), revisao AS (
    -- Preserva comportamento original: duração sem correspondência vira zero.
    -- Isso pode produzir falsa revisão: limitação registrada na documentação.
    SELECT p.aluno_id, COUNT(DISTINCT p.aula_id) AS qtd_aula_revistas
    FROM v3_v1_src_aulas p
    LEFT JOIN v3_v1_src_duracao d
      ON p.curso_id = d.curso_id AND p.modulo_id = d.modulo_id AND p.aula_id = d.aula_id
    WHERE p.tempo_segundos > COALESCE(d.duracao_segundos, 0)
    GROUP BY p.aluno_id
), recencia AS (
    SELECT p.aluno_id,
           DATEDIFF(c.data_referencia,
                    MAX(COALESCE(CAST(p.ultimo_acesso_ts AS DATE), a.cadastro_data))) AS Dias_Recencia
    FROM v3_v1_src_progresso p
    INNER JOIN v3_v1_src_alunos a ON p.matricula_id = a.matricula_id
    CROSS JOIN v3_v1_cfg c
    GROUP BY p.aluno_id, c.data_referencia
), spine AS (
    -- Fiel à seleção original: todos os IDs de alunos_geral, sem excluir gratuitos/teste.
    SELECT DISTINCT aluno_id FROM v3_v1_src_alunos
)
SELECT s.aluno_id AS aluno, c.data_referencia,
       COALESCE(f.Frequencia_Dias, 0) AS Frequencia_Dias,
       COALESCE(p.velocidade_progresso, 0.0) AS velocidade_progresso,
       p.progresso_plataforma_absoluto, p.qtd_cursos_ativos, p.dias_de_casa,
       COALESCE(d.profundidade_total_segundos, 0) AS profundidade_total_segundos,
       COALESCE(r.Dias_Recencia, 0) AS Dias_Recencia,
       COALESCE(v.qtd_aula_revistas, 0) AS qtd_aula_revistas
FROM spine s
CROSS JOIN v3_v1_cfg c
LEFT JOIN frequencia f ON s.aluno_id = f.aluno_id
LEFT JOIN dm_progresso p ON s.aluno_id = p.aluno_id
LEFT JOIN profundidade d ON s.aluno_id = d.aluno_id
LEFT JOIN recencia r ON s.aluno_id = r.aluno_id
LEFT JOIN revisao v ON s.aluno_id = v.aluno_id;

-- COMMAND ----------
CREATE OR REPLACE TEMP VIEW v3_v1_estatisticas_grupo AS
SELECT
    PERCENTILE_APPROX(Frequencia_Dias, ARRAY(0.25,0.75),10000) AS freq_q,
    AVG(Frequencia_Dias) AS freq_media, STDDEV_SAMP(Frequencia_Dias) AS freq_std,
    PERCENTILE_APPROX(velocidade_progresso, ARRAY(0.25,0.75),10000) AS prog_q,
    AVG(velocidade_progresso) AS prog_media, STDDEV_SAMP(velocidade_progresso) AS prog_std,
    PERCENTILE_APPROX(profundidade_total_segundos, ARRAY(0.25,0.75),10000) AS prof_q,
    AVG(profundidade_total_segundos) AS prof_media, STDDEV_SAMP(profundidade_total_segundos) AS prof_std,
    PERCENTILE_APPROX(Dias_Recencia, ARRAY(0.25,0.75),10000) AS rec_q,
    AVG(Dias_Recencia) AS rec_media, STDDEV_SAMP(Dias_Recencia) AS rec_std,
    PERCENTILE_APPROX(qtd_aula_revistas, ARRAY(0.25,0.75),10000) AS rev_q,
    AVG(qtd_aula_revistas) AS rev_media, STDDEV_SAMP(qtd_aula_revistas) AS rev_std
FROM v3_v1_metricas_grupo;

-- COMMAND ----------
CREATE OR REPLACE TEMP VIEW v3_v1_resultado_grupo AS
WITH padronizada AS (
    SELECT m.*,
        CASE WHEN Frequencia_Dias <= GET(e.freq_q,0) THEN 'Baixo'
             WHEN Frequencia_Dias >= GET(e.freq_q,1) THEN 'Alto' ELSE 'Medio' END AS frequencia,
        CASE WHEN velocidade_progresso <= GET(e.prog_q,0) THEN 'Baixo'
             WHEN velocidade_progresso >= GET(e.prog_q,1) THEN 'Alto' ELSE 'Medio' END AS progresso,
        CASE WHEN profundidade_total_segundos <= GET(e.prof_q,0) THEN 'Baixo'
             WHEN profundidade_total_segundos >= GET(e.prof_q,1) THEN 'Alto' ELSE 'Medio' END AS profundidade,
        CASE WHEN Dias_Recencia <= GET(e.rec_q,0) THEN 'Alto'
             WHEN Dias_Recencia >= GET(e.rec_q,1) THEN 'Baixo' ELSE 'Medio' END AS recencia,
        CASE WHEN qtd_aula_revistas <= GET(e.rev_q,0) THEN 'Baixo'
             WHEN qtd_aula_revistas >= GET(e.rev_q,1) THEN 'Alto' ELSE 'Medio' END AS revisao,
        -- NULLIF expõe desvio zero como NULL sem abortar a execução.
        (Frequencia_Dias - e.freq_media) / NULLIF(e.freq_std,0) AS frequencia_pr,
        (velocidade_progresso - e.prog_media) / NULLIF(e.prog_std,0) AS progresso_pr,
        (profundidade_total_segundos - e.prof_media) / NULLIF(e.prof_std,0) AS profundidade_pr,
        (e.rec_media - Dias_Recencia) / NULLIF(e.rec_std,0) AS recencia_pr,
        (qtd_aula_revistas - e.rev_media) / NULLIF(e.rev_std,0) AS revisao_pr
    FROM v3_v1_metricas_grupo m CROSS JOIN v3_v1_estatisticas_grupo e
), ponderada AS (
    SELECT *, frequencia_pr * 0.20 AS frequencia_peso,
              progresso_pr * 0.20 AS progresso_peso,
              profundidade_pr * 0.10 AS profundidade_peso,
              recencia_pr * 0.40 AS recencia_peso,
              revisao_pr * 0.10 AS revisao_peso
    FROM padronizada
), pontuada AS (
    SELECT *, frequencia_peso + progresso_peso + profundidade_peso
              + recencia_peso + revisao_peso AS score_classificao
    FROM ponderada
)
SELECT *, CASE
    WHEN recencia = 'Baixo' THEN 'Alto Risco'
    WHEN score_classificao <= -1.5 THEN 'Alto Risco'
    WHEN score_classificao <= -0.5 THEN 'Em Risco'
    WHEN score_classificao <= 0.5 THEN 'Parcial'
    WHEN score_classificao <= 1.5 THEN 'Acima da Média'
    WHEN score_classificao > 1.5 THEN 'Engajado'
    ELSE 'Não Classificado' END AS classificao_ordinal
FROM pontuada;

-- COMMAND ----------

-- 3. V2: elegibilidade e metricas interpretaveis.
CREATE OR REPLACE TEMP VIEW v3_v2_alunos_geral_filtrado AS
WITH cursos_distintos AS (
    SELECT aluno_id, COUNT(DISTINCT curso_id) AS qtd_cursos_distintos
    FROM v3_v2_alunos_geral
    GROUP BY aluno_id
),
somente_curso_96 AS (
    SELECT c.aluno_id
    FROM cursos_distintos c
    JOIN v3_v2_alunos_geral a ON c.aluno_id = a.aluno_id
    WHERE c.qtd_cursos_distintos = 1 AND a.curso_id = 96
    GROUP BY c.aluno_id
)
SELECT DISTINCT aluno_id
FROM v3_v2_alunos_geral
WHERE aluno_id NOT IN (SELECT aluno_id FROM somente_curso_96)
  AND aluno_id != 466;
-- COMMAND ----------
-- V2 celula 60: EXISTS evita multiplicar consumo por matriculas duplicadas.
CREATE OR REPLACE TEMP VIEW v3_v2_progresso_total_filtrado AS
SELECT p.* FROM v3_v2_progresso_total p
WHERE EXISTS (SELECT 1 FROM v3_v2_alunos_geral_filtrado s WHERE s.aluno_id=p.aluno_id)
AND EXISTS (SELECT 1 FROM v3_v2_alunos_geral a WHERE a.aluno_id=p.aluno_id
            AND a.curso_id=p.curso_id AND a.status='Matrícula ativa');

-- COMMAND ----------
-- V2: celula 13 (indice zero) do DBC original.
CREATE OR REPLACE TEMP VIEW v3_v2_progresso_evolucao_mensal AS
SELECT p.*
FROM v3_v2_progresso_total_filtrado p
WHERE p.curso_id NOT IN (94, 29, 62, 80);

-- COMMAND ----------
-- V2: celula 12 (indice zero) do DBC original.
CREATE OR REPLACE TEMP VIEW v3_v2_progresso_com_percentual AS
SELECT
    p.*,
    d.duracao_segundos,
    (TRY_CAST(SPLIT_PART(p.tempo_aula, ':', 1) AS INTEGER) * 3600
        + TRY_CAST(SPLIT_PART(p.tempo_aula, ':', 2) AS INTEGER) * 60
        + TRY_CAST(SPLIT_PART(p.tempo_aula, ':', 3) AS INTEGER)) AS tempo_aula_segundos,
    CASE
        WHEN d.duracao_segundos IS NULL OR d.duracao_segundos = 0 THEN NULL
        WHEN TRY_CAST(SPLIT_PART(p.tempo_aula, ':', 1) AS INTEGER) IS NULL THEN NULL
        ELSE (TRY_CAST(SPLIT_PART(p.tempo_aula, ':', 1) AS INTEGER) * 3600
                + TRY_CAST(SPLIT_PART(p.tempo_aula, ':', 2) AS INTEGER) * 60
                + TRY_CAST(SPLIT_PART(p.tempo_aula, ':', 3) AS INTEGER)) / d.duracao_segundos
    END AS percentual_assistido,
    CASE
        WHEN d.duracao_segundos IS NULL OR d.duracao_segundos = 0 THEN FALSE
        WHEN TRY_CAST(SPLIT_PART(p.tempo_aula, ':', 1) AS INTEGER) IS NULL THEN FALSE
        WHEN (TRY_CAST(SPLIT_PART(p.tempo_aula, ':', 1) AS INTEGER) * 3600
                + TRY_CAST(SPLIT_PART(p.tempo_aula, ':', 2) AS INTEGER) * 60
                + TRY_CAST(SPLIT_PART(p.tempo_aula, ':', 3) AS INTEGER)) / d.duracao_segundos
             >= CAST((SELECT percentual_minimo_assistido FROM v3_cfg) AS DOUBLE) THEN TRUE
        ELSE FALSE
    END AS aula_assistida
FROM v3_v2_progresso_evolucao_mensal p
LEFT JOIN v3_v2_asn_aulas_duracao d
    ON p.curso_id = d.curso_id
    AND p.aula_id = d.aula_id;

-- COMMAND ----------
-- V2: celula 74 (indice zero) do DBC original.
CREATE OR REPLACE TEMP VIEW v3_v2_atividade_mensal_volume AS
SELECT DISTINCT
    aluno_id,
    curso_id,
    modulo_id,
    aula_id,
    DATE_FORMAT(DATE(TRY_CAST(data_conclusao AS TIMESTAMP)), 'yyyy-MM') AS mes_atividade
FROM v3_v2_progresso_com_percentual
WHERE aula_assistida = TRUE
  AND TRY_CAST(data_conclusao AS TIMESTAMP) IS NOT NULL;

-- COMMAND ----------
-- V2: celula 73 (indice zero) do DBC original.
CREATE OR REPLACE TEMP VIEW v3_v2_volume_mensal AS
SELECT
    aluno_id,
    mes_atividade,
    COUNT(DISTINCT curso_id) AS cursos_distintos,
    COUNT(DISTINCT aula_id) AS aulas_distintas
FROM v3_v2_atividade_mensal_volume
GROUP BY aluno_id, mes_atividade
ORDER BY aluno_id, mes_atividade;

-- COMMAND ----------
-- V2: celula 72 (indice zero) do DBC original.
CREATE OR REPLACE TEMP VIEW v3_v2_volume_final AS
WITH data_matricula_aluno AS (
    SELECT
        aluno_id,
        GREATEST(DATE((SELECT data_inicio FROM v3_cfg)), MAX(DATE(TRY_CAST(cadastro AS TIMESTAMP)))) AS data_matricula
    FROM v3_v2_alunos_geral
    WHERE aluno_id IN (SELECT aluno_id FROM v3_v2_alunos_geral_filtrado)
      AND TRY_CAST(cadastro AS TIMESTAMP) IS NOT NULL
    GROUP BY aluno_id
),
periodo_aluno AS (
    SELECT
        t.aluno_id,
        m.data_matricula,
        CAST(
            (YEAR(DATE((SELECT data_fim FROM v3_cfg))) - YEAR(m.data_matricula)) * 12
            + (MONTH(DATE((SELECT data_fim FROM v3_cfg))) - MONTH(m.data_matricula))
        AS INT) + 1 AS qtd_meses
    FROM v3_v2_alunos_geral_filtrado t
    JOIN data_matricula_aluno m ON t.aluno_id = m.aluno_id
),
grade_meses AS (
    SELECT
        p.aluno_id,
        p.data_matricula,
        CAST(DATE_TRUNC('MONTH', ADD_MONTHS(p.data_matricula, i)) AS DATE) AS inicio_mes,
        DATE_FORMAT(ADD_MONTHS(p.data_matricula, i), 'yyyy-MM') AS mes_atividade
    FROM periodo_aluno p
    LATERAL VIEW explode(sequence(0, p.qtd_meses - 1)) AS i
),
grade_com_dias AS (
    SELECT
        g.aluno_id,
        g.mes_atividade,
        DATEDIFF(
            LEAST(LAST_DAY(g.inicio_mes), DATE((SELECT data_fim FROM v3_cfg))),
            GREATEST(g.inicio_mes, g.data_matricula)
        ) + 1 AS dias_com_dados_no_mes
    FROM grade_meses g
),
acesso_mensal AS (
    SELECT DISTINCT
        aluno_id,
        DATE_FORMAT(DATE(TRY_CAST(data_conclusao AS TIMESTAMP)), 'yyyy-MM') AS mes_atividade
    FROM v3_v2_progresso_com_percentual
    WHERE TRY_CAST(data_conclusao AS TIMESTAMP) IS NOT NULL
)
SELECT
    g.aluno_id,
    g.mes_atividade,
    CASE
        WHEN a.aluno_id IS NULL THEN NULL
        WHEN v.cursos_distintos IS NULL THEN CAST(0 AS DECIMAL(18,6))
        ELSE CAST(CAST(v.cursos_distintos AS DOUBLE) / g.dias_com_dados_no_mes AS DECIMAL(18,6))
    END AS cursos_distintos_taxa,
    CASE
        WHEN a.aluno_id IS NULL THEN NULL
        WHEN v.aulas_distintas IS NULL THEN CAST(0 AS DECIMAL(18,6))
        ELSE CAST(CAST(v.aulas_distintas AS DOUBLE) / g.dias_com_dados_no_mes AS DECIMAL(18,6))
    END AS aulas_distintas_taxa
FROM grade_com_dias g
LEFT JOIN v3_v2_volume_mensal v ON g.aluno_id = v.aluno_id AND g.mes_atividade = v.mes_atividade
LEFT JOIN acesso_mensal a ON g.aluno_id = a.aluno_id AND g.mes_atividade = a.mes_atividade
ORDER BY g.aluno_id, g.mes_atividade;

-- COMMAND ----------
-- V2: celula 71 (indice zero) do DBC original.
CREATE OR REPLACE TEMP VIEW v3_v2_atividade_mensal_tempo AS
SELECT
    aluno_id,
    curso_id,
    modulo_id,
    aula_id,
    DATE_FORMAT(DATE(TRY_CAST(data_conclusao AS TIMESTAMP)), 'yyyy-MM') AS mes_atividade,
    LEAST(tempo_aula_segundos, duracao_segundos) AS tempo_computado_segundos
FROM v3_v2_progresso_com_percentual
WHERE TRY_CAST(data_conclusao AS TIMESTAMP) IS NOT NULL
  AND tempo_aula_segundos IS NOT NULL
  AND duracao_segundos IS NOT NULL;

-- COMMAND ----------
-- V2: celula 70 (indice zero) do DBC original.
CREATE OR REPLACE TEMP VIEW v3_v2_tempo_mensal AS
SELECT
    aluno_id,
    mes_atividade,
    SUM(tempo_computado_segundos) AS tempo_total_segundos
FROM v3_v2_atividade_mensal_tempo
GROUP BY aluno_id, mes_atividade
ORDER BY aluno_id, mes_atividade;

-- COMMAND ----------
-- V2: celula 69 (indice zero) do DBC original.
CREATE OR REPLACE TEMP VIEW v3_v2_tempo_final AS
WITH data_matricula_aluno AS (
    SELECT
        aluno_id,
        GREATEST(DATE((SELECT data_inicio FROM v3_cfg)), MAX(DATE(TRY_CAST(cadastro AS TIMESTAMP)))) AS data_matricula
    FROM v3_v2_alunos_geral
    WHERE aluno_id IN (SELECT aluno_id FROM v3_v2_alunos_geral_filtrado)
      AND TRY_CAST(cadastro AS TIMESTAMP) IS NOT NULL
    GROUP BY aluno_id
),
periodo_aluno AS (
    SELECT
        t.aluno_id,
        m.data_matricula,
        CAST(
            (YEAR(DATE((SELECT data_fim FROM v3_cfg))) - YEAR(m.data_matricula)) * 12
            + (MONTH(DATE((SELECT data_fim FROM v3_cfg))) - MONTH(m.data_matricula))
        AS INT) + 1 AS qtd_meses
    FROM v3_v2_alunos_geral_filtrado t
    JOIN data_matricula_aluno m ON t.aluno_id = m.aluno_id
),
grade_meses AS (
    SELECT
        p.aluno_id,
        p.data_matricula,
        CAST(DATE_TRUNC('MONTH', ADD_MONTHS(p.data_matricula, i)) AS DATE) AS inicio_mes,
        DATE_FORMAT(ADD_MONTHS(p.data_matricula, i), 'yyyy-MM') AS mes_atividade
    FROM periodo_aluno p
    LATERAL VIEW explode(sequence(0, p.qtd_meses - 1)) AS i
),
grade_com_dias AS (
    SELECT
        g.aluno_id,
        g.mes_atividade,
        DATEDIFF(
            LEAST(LAST_DAY(g.inicio_mes), DATE((SELECT data_fim FROM v3_cfg))),
            GREATEST(g.inicio_mes, g.data_matricula)
        ) + 1 AS dias_com_dados_no_mes
    FROM grade_meses g
),
acesso_mensal AS (
    SELECT DISTINCT
        aluno_id,
        DATE_FORMAT(DATE(TRY_CAST(data_conclusao AS TIMESTAMP)), 'yyyy-MM') AS mes_atividade
    FROM v3_v2_progresso_com_percentual
    WHERE TRY_CAST(data_conclusao AS TIMESTAMP) IS NOT NULL
)
SELECT
    g.aluno_id,
    g.mes_atividade,
    CASE
        WHEN a.aluno_id IS NULL THEN NULL
        WHEN t.tempo_total_segundos IS NULL THEN CAST(0 AS DECIMAL(18,6))
        ELSE CAST((t.tempo_total_segundos / 3600.0) / g.dias_com_dados_no_mes AS DECIMAL(18,6))
    END AS tempo_horas_taxa
FROM grade_com_dias g
LEFT JOIN v3_v2_tempo_mensal t ON g.aluno_id = t.aluno_id AND g.mes_atividade = t.mes_atividade
LEFT JOIN acesso_mensal a ON g.aluno_id = a.aluno_id AND g.mes_atividade = a.mes_atividade
ORDER BY g.aluno_id, g.mes_atividade;

-- COMMAND ----------
-- V2: celula 0 (indice zero) do DBC original.
CREATE OR REPLACE TEMP VIEW v3_v2_metrica_recencia AS
WITH recencia_calculada AS (
    SELECT
        aluno_id,
        MAX(ultima_visualizacao) AS ultima_visualizacao,
        CAST(DATEDIFF(TRY_CAST((SELECT data_fim FROM v3_cfg) AS DATE), TRY_CAST(MAX(ultima_visualizacao) AS DATE)) AS DECIMAL(18,6)) AS recencia
    FROM v3_v2_progresso_total_filtrado
    GROUP BY aluno_id
)
SELECT
    t.aluno_id,
    r.ultima_visualizacao,
    r.recencia AS recencia
FROM v3_v2_alunos_geral_filtrado t
LEFT JOIN recencia_calculada r ON t.aluno_id = r.aluno_id;

-- COMMAND ----------
-- V2: celula 24 (indice zero) do DBC original.
CREATE OR REPLACE TEMP VIEW v3_v2_metrica_historico AS
WITH data_matricula_aluno AS (
    SELECT
        ag.aluno_id,
        GREATEST(DATE((SELECT data_inicio FROM v3_cfg)), MAX(DATE(TRY_CAST(a.cadastro AS TIMESTAMP)))) AS data_matricula
    FROM v3_v2_alunos_geral_filtrado ag
    JOIN v3_v2_alunos_geral a ON ag.aluno_id = a.aluno_id
    WHERE TRY_CAST(a.cadastro AS TIMESTAMP) IS NOT NULL
    GROUP BY ag.aluno_id
),
datas_acesso AS (
    SELECT
        aluno_id,
        DATE(ultima_visualizacao) AS data_acesso
    FROM v3_v2_progresso_total_filtrado
    WHERE ultima_visualizacao IS NOT NULL
    UNION
    SELECT
        aluno_id,
        DATE(TRY_CAST(data_conclusao AS TIMESTAMP)) AS data_acesso
    FROM v3_v2_progresso_total_filtrado
    WHERE TRY_CAST(data_conclusao AS TIMESTAMP) IS NOT NULL
),
datas_unicas AS (
    SELECT DISTINCT
        aluno_id,
        data_acesso
    FROM datas_acesso
),
qtd_datas_reais AS (
    SELECT aluno_id, COUNT(*) AS qtd_datas_distintas
    FROM datas_unicas
    GROUP BY aluno_id
),
acessos_com_periodo AS (
    SELECT
        d.aluno_id,
        d.data_acesso,
        CAST(FLOOR(DATEDIFF(d.data_acesso, m.data_matricula) / CAST((SELECT tamanho_periodo FROM v3_cfg) AS DOUBLE)) AS INT) + 1 AS periodo
    FROM datas_unicas d
    JOIN data_matricula_aluno m ON d.aluno_id = m.aluno_id
    WHERE d.data_acesso >= m.data_matricula
),
contagem_por_periodo AS (
    SELECT aluno_id, periodo, COUNT(*) AS acessos
    FROM acessos_com_periodo
    GROUP BY aluno_id, periodo
),
total_periodos AS (
    SELECT
        m.aluno_id,
        CAST(CEIL((DATEDIFF(DATE((SELECT data_fim FROM v3_cfg)), m.data_matricula) + 1) / CAST((SELECT tamanho_periodo FROM v3_cfg) AS DOUBLE)) AS INT) AS max_periodo
    FROM data_matricula_aluno m
),
grade_periodos AS (
    SELECT t.aluno_id, gs AS periodo
    FROM total_periodos t
    LATERAL VIEW explode(sequence(1, t.max_periodo)) AS gs
),
grade_com_acessos AS (
    SELECT
        g.aluno_id,
        g.periodo,
        COALESCE(c.acessos, 0) AS acessos
    FROM grade_periodos g
    LEFT JOIN contagem_por_periodo c
        ON g.aluno_id = c.aluno_id AND g.periodo = c.periodo
),
slope_calc AS (
    SELECT
        aluno_id,
        regr_slope(acessos, periodo) AS slope,
        regr_r2(acessos, periodo) AS r2
    FROM grade_com_acessos
    GROUP BY aluno_id
)
SELECT
    t.aluno_id,
    CASE
        WHEN q.qtd_datas_distintas IS NULL OR q.qtd_datas_distintas < 2 THEN NULL
        ELSE CAST(s.slope AS DECIMAL(18,6))
    END AS tendencia_acessos,
    CASE
        WHEN q.qtd_datas_distintas IS NULL OR q.qtd_datas_distintas < 2 THEN NULL
        ELSE CAST(s.r2 AS DECIMAL(18,6))
    END AS r2_hist_acessos
FROM v3_v2_alunos_geral_filtrado t
LEFT JOIN qtd_datas_reais q ON t.aluno_id = q.aluno_id
LEFT JOIN slope_calc s ON t.aluno_id = s.aluno_id
ORDER BY t.aluno_id;

-- COMMAND ----------
-- V2: celula 30 (indice zero) do DBC original.
CREATE OR REPLACE TEMP VIEW v3_v2_metrica_acessos AS
WITH data_inicio_aluno AS (
    SELECT
        ag.aluno_id,
        GREATEST(DATE((SELECT data_inicio FROM v3_cfg)), MAX(DATE(a.cadastro))) AS data_inicio_efetiva
    FROM v3_v2_alunos_geral_filtrado ag
    JOIN v3_v2_alunos_geral a ON ag.aluno_id = a.aluno_id
    GROUP BY ag.aluno_id
),
aulas AS (
    SELECT
        p.aluno_id,
        p.ultima_visualizacao,
        TRY_CAST(p.data_conclusao AS TIMESTAMP) AS data_conclusao_ts,
        CASE
            WHEN d.duracao_segundos IS NULL OR d.duracao_segundos = 0 THEN 0
            WHEN (TRY_CAST(SPLIT_PART(p.tempo_aula, ':', 1) AS INTEGER) * 3600
                    + TRY_CAST(SPLIT_PART(p.tempo_aula, ':', 2) AS INTEGER) * 60
                    + TRY_CAST(SPLIT_PART(p.tempo_aula, ':', 3) AS INTEGER)) / d.duracao_segundos
                 >= CAST((SELECT percentual_minimo_assistido FROM v3_cfg) AS DOUBLE) THEN 1
            ELSE 0
        END AS aula_assistida
    FROM v3_v2_progresso_total_filtrado p
    LEFT JOIN v3_v2_asn_aulas_duracao d
        ON p.curso_id = d.curso_id AND p.aula_id = d.aula_id
),
datas_acesso AS (
    SELECT
        a.aluno_id,
        DATE(a.ultima_visualizacao) AS data_acesso,
        a.aula_assistida
    FROM aulas a
    JOIN data_inicio_aluno d ON a.aluno_id = d.aluno_id
    WHERE a.ultima_visualizacao IS NOT NULL
      AND DATE(a.ultima_visualizacao) BETWEEN d.data_inicio_efetiva AND (SELECT data_fim FROM v3_cfg)
    UNION ALL
    SELECT
        a.aluno_id,
        DATE(a.data_conclusao_ts) AS data_acesso,
        a.aula_assistida
    FROM aulas a
    JOIN data_inicio_aluno d ON a.aluno_id = d.aluno_id
    WHERE a.data_conclusao_ts IS NOT NULL
      AND DATE(a.data_conclusao_ts) BETWEEN d.data_inicio_efetiva AND (SELECT data_fim FROM v3_cfg)
),
dias_acesso AS (
    SELECT
        aluno_id,
        data_acesso,
        MAX(aula_assistida) AS dia_aproveitado
    FROM datas_acesso
    GROUP BY aluno_id, data_acesso
),
contagem AS (
    SELECT
        aluno_id,
        COUNT(*) AS numero_acessos_dias_distintos,
        SUM(dia_aproveitado) AS dias_aproveitados
    FROM dias_acesso
    GROUP BY aluno_id
)
SELECT
    t.aluno_id,
    COALESCE(c.numero_acessos_dias_distintos, 0) AS numero_acessos_dias_distintos,
    CASE
        WHEN COALESCE(c.numero_acessos_dias_distintos, 0) = 0 THEN NULL
        ELSE CAST(c.dias_aproveitados * 1.0 / c.numero_acessos_dias_distintos AS DECIMAL(18,6))
    END AS taxa_aproveit_acessos
FROM v3_v2_alunos_geral_filtrado t
LEFT JOIN contagem c ON t.aluno_id = c.aluno_id
ORDER BY t.aluno_id;

-- COMMAND ----------
-- V2: celula 32 (indice zero) do DBC original.
CREATE OR REPLACE TEMP VIEW v3_v2_metrica_cadastro AS
SELECT
    t.aluno_id,
    DATE(u.data_cadastro) AS data_cadastro,
    DATEDIFF(DATE((SELECT data_fim FROM v3_cfg)), DATE(u.data_cadastro)) AS dias_cadastro
FROM v3_v2_alunos_geral_filtrado t
LEFT JOIN v3_v2_usuarios_geral u ON t.aluno_id = u.aluno_id
ORDER BY t.aluno_id;

-- COMMAND ----------
-- V2: celula 33 (indice zero) do DBC original.
CREATE OR REPLACE TEMP VIEW v3_v2_metrica_progresso_velocidade AS
WITH base AS (
    SELECT
        p.aluno_id, p.curso_id, p.aula_id,
        p.ultima_visualizacao, p.data_conclusao, p.tempo_aula,
        d.duracao_segundos
    FROM v3_v2_progresso_total_filtrado p
    JOIN v3_v2_asn_aulas_duracao d ON p.curso_id = d.curso_id AND p.aula_id = d.aula_id
    WHERE p.curso_id NOT IN (94, 29, 62, 80)
),
tempo_disponivel AS (
    SELECT
        a.aluno_id,
        CAST(SUM(d.duracao_segundos) AS BIGINT) AS tempo_disponivel_segundos
    FROM (SELECT DISTINCT aluno_id, curso_id, status FROM v3_v2_alunos_geral) a
    JOIN v3_v2_asn_aulas_duracao d ON a.curso_id = d.curso_id
    WHERE a.status = 'Matrícula ativa'
      AND a.curso_id NOT IN (94, 29, 62, 80)
      AND a.aluno_id IN (SELECT aluno_id FROM v3_v2_alunos_geral_filtrado)
    GROUP BY a.aluno_id
),
esforco AS (
    WITH tempo_por_aula AS (
        SELECT
            aluno_id, curso_id, aula_id,
            LEAST(
                SUM(COALESCE(
                    TRY_CAST(get(SPLIT(tempo_aula, ':'), 0) AS BIGINT) * 3600 +
                    TRY_CAST(get(SPLIT(tempo_aula, ':'), 1) AS BIGINT) * 60 +
                    TRY_CAST(get(SPLIT(tempo_aula, ':'), 2) AS BIGINT),
                    0
                )),
                MAX(duracao_segundos)
            ) AS tempo_limitado
        FROM base
        GROUP BY aluno_id, curso_id, aula_id
    )
    SELECT aluno_id, CAST(SUM(tempo_limitado) AS BIGINT) AS esforco_segundos
    FROM tempo_por_aula
    GROUP BY aluno_id
),
primeiro_acesso AS (
    SELECT aluno_id, MIN(data_acesso) AS data_inicio
    FROM (
        SELECT aluno_id, DATE(ultima_visualizacao) AS data_acesso
        FROM base WHERE ultima_visualizacao IS NOT NULL
        UNION
        SELECT aluno_id, DATE(TRY_CAST(data_conclusao AS TIMESTAMP)) AS data_acesso
        FROM base WHERE TRY_CAST(data_conclusao AS TIMESTAMP) IS NOT NULL
    ) t
    GROUP BY aluno_id
)
SELECT
    t.aluno_id,
    CASE
        WHEN e.aluno_id IS NULL THEN NULL
        ELSE CAST((e.esforco_segundos * 100.0 / NULLIF(td.tempo_disponivel_segundos,0)) AS DECIMAL(18,6))
    END AS progresso,
    CASE
        WHEN e.aluno_id IS NULL THEN NULL
        ELSE CAST((e.esforco_segundos * 100.0 / NULLIF(td.tempo_disponivel_segundos,0)) / GREATEST(DATEDIFF(DATE((SELECT data_fim FROM v3_cfg)), p.data_inicio), 1)
        AS DECIMAL(18,6))
    END AS velocidade
FROM v3_v2_alunos_geral_filtrado t
LEFT JOIN tempo_disponivel td ON t.aluno_id = td.aluno_id
LEFT JOIN esforco e ON t.aluno_id = e.aluno_id
LEFT JOIN primeiro_acesso p ON t.aluno_id = p.aluno_id
ORDER BY t.aluno_id;

-- COMMAND ----------
-- V2: celula 42 (indice zero) do DBC original.
CREATE OR REPLACE TEMP VIEW v3_v2_metrica_cursos AS
WITH base AS (
    SELECT
        p.aluno_id, p.curso_id, p.aula_id,
        p.tempo_aula, d.duracao_segundos
    FROM v3_v2_progresso_total_filtrado p
    JOIN v3_v2_asn_aulas_duracao d ON p.curso_id = d.curso_id AND p.aula_id = d.aula_id
    WHERE p.curso_id NOT IN (94, 29, 62, 80)
),
tempo_por_aula AS (
    SELECT
        aluno_id, curso_id, aula_id,
        LEAST(
            SUM(COALESCE(
                TRY_CAST(get(SPLIT(tempo_aula, ':'), 0) AS BIGINT) * 3600 +
                TRY_CAST(get(SPLIT(tempo_aula, ':'), 1) AS BIGINT) * 60 +
                TRY_CAST(get(SPLIT(tempo_aula, ':'), 2) AS BIGINT),
                0
            )),
            MAX(duracao_segundos)
        ) AS tempo_limitado,
        MAX(duracao_segundos) AS duracao_aula
    FROM base
    GROUP BY aluno_id, curso_id, aula_id
),
duracao_curso AS (
    SELECT curso_id, CAST(SUM(duracao_segundos) AS BIGINT) AS duracao_curso_segundos
    FROM v3_v2_asn_aulas_duracao
    GROUP BY curso_id
),
por_curso AS (
    SELECT
        t.aluno_id, t.curso_id,
        SUM(t.tempo_limitado) AS tempo_curso,
        MAX(CASE WHEN t.duracao_aula > 0
                  AND t.tempo_limitado * 1.0 / t.duracao_aula >= CAST((SELECT percentual_minimo_assistido FROM v3_cfg) AS DOUBLE)
                 THEN 1 ELSE 0 END) AS tem_aula_assistida,
        MAX(c.duracao_curso_segundos) AS duracao_curso_segundos
    FROM tempo_por_aula t
    JOIN duracao_curso c ON t.curso_id = c.curso_id
    GROUP BY t.aluno_id, t.curso_id
),
classificacao AS (
    SELECT
        aluno_id,
        CASE WHEN duracao_curso_segundos > 0
              AND tempo_curso * 1.0 / duracao_curso_segundos >= 0.75 THEN 1 ELSE 0 END AS concluido,
        CASE WHEN NOT (duracao_curso_segundos > 0
                       AND tempo_curso * 1.0 / duracao_curso_segundos >= 0.75)
              AND tem_aula_assistida = 1 THEN 1 ELSE 0 END AS em_andamento
    FROM por_curso
),
contagem AS (
    SELECT
        aluno_id,
        SUM(concluido) AS cursos_concluidos,
        SUM(em_andamento) AS cursos_andamento
    FROM classificacao
    GROUP BY aluno_id
)
SELECT
    t.aluno_id,
    CAST(c.cursos_concluidos AS INT) AS cursos_concluidos,
    CAST(c.cursos_andamento AS INT) AS cursos_andamento
FROM v3_v2_alunos_geral_filtrado t
LEFT JOIN contagem c ON t.aluno_id = c.aluno_id
ORDER BY t.aluno_id;

-- COMMAND ----------
-- V2: celula 56 (indice zero) do DBC original.
CREATE OR REPLACE TEMP VIEW v3_v2_metrica_frequencia AS
WITH datas_acesso AS (
    SELECT
        aluno_id,
        DATE(ultima_visualizacao) AS data_acesso
    FROM v3_v2_progresso_total_filtrado
    WHERE ultima_visualizacao IS NOT NULL
    UNION
    SELECT
        aluno_id,
        DATE(TRY_CAST(data_conclusao AS TIMESTAMP)) AS data_acesso
    FROM v3_v2_progresso_total_filtrado
    WHERE TRY_CAST(data_conclusao AS TIMESTAMP) IS NOT NULL
),
datas_unicas AS (
    SELECT DISTINCT
        aluno_id,
        data_acesso
    FROM datas_acesso
),
intervalos AS (
    SELECT
        aluno_id,
        data_acesso,
        DATEDIFF(
            data_acesso,
            LAG(data_acesso) OVER (
                PARTITION BY aluno_id
                ORDER BY data_acesso
            )
        ) AS intervalo_dias
    FROM datas_unicas
),
frequencia AS (
    SELECT
        aluno_id,
        CAST(AVG(intervalo_dias) AS DECIMAL(18,6)) AS frequencia_media_dias
    FROM intervalos
    WHERE intervalo_dias IS NOT NULL
    GROUP BY aluno_id
)
SELECT
    t.aluno_id,
    f.frequencia_media_dias AS frequencia_media_dias
FROM v3_v2_alunos_geral_filtrado t
LEFT JOIN frequencia f ON t.aluno_id = f.aluno_id
ORDER BY t.aluno_id;

-- COMMAND ----------
-- V2: celula 29 (indice zero) do DBC original.
CREATE OR REPLACE TEMP VIEW v3_v2_evolucao_mensal_slope AS
WITH volume_numerico AS (
    SELECT
        aluno_id,
        mes_atividade,
        ROW_NUMBER() OVER (PARTITION BY aluno_id ORDER BY mes_atividade) AS periodo,
        cursos_distintos_taxa AS cursos_distintos_num,
        aulas_distintas_taxa AS aulas_distintas_num
    FROM v3_v2_volume_final
),
tempo_numerico AS (
    SELECT
        aluno_id,
        mes_atividade,
        tempo_horas_taxa AS tempo_horas_num
    FROM v3_v2_tempo_final
),
base_slope AS (
    SELECT
        v.aluno_id, v.periodo,
        v.cursos_distintos_num, v.aulas_distintas_num, t.tempo_horas_num
    FROM volume_numerico v
    JOIN tempo_numerico t ON v.aluno_id = t.aluno_id AND v.mes_atividade = t.mes_atividade
),
contagem_pontos AS (
    SELECT aluno_id, COUNT(cursos_distintos_num) AS qtd_pontos_validos
    FROM base_slope
    GROUP BY aluno_id
),
slope_calc AS (
    SELECT
        aluno_id,
        regr_slope(cursos_distintos_num, periodo) AS taxa_slope_cursos,
        regr_r2(cursos_distintos_num, periodo) AS taxa_r2_cursos,
        regr_slope(aulas_distintas_num, periodo) AS taxa_slope_aulas,
        regr_r2(aulas_distintas_num, periodo) AS taxa_r2_aulas,
        regr_slope(tempo_horas_num, periodo) AS taxa_slope_tempo,
        regr_r2(tempo_horas_num, periodo) AS taxa_r2_tempo
    FROM base_slope
    GROUP BY aluno_id
)
SELECT
    c.aluno_id,
    CASE WHEN c.qtd_pontos_validos < 2 THEN NULL
         ELSE CAST(s.taxa_slope_cursos AS DECIMAL(18,6)) END AS taxa_slope_cursos,
    CASE WHEN c.qtd_pontos_validos < 2 THEN NULL
         ELSE CAST(s.taxa_r2_cursos AS DECIMAL(18,6)) END AS taxa_r2_cursos,
    CASE WHEN c.qtd_pontos_validos < 2 THEN NULL
         ELSE CAST(s.taxa_slope_aulas AS DECIMAL(18,6)) END AS taxa_slope_aulas,
    CASE WHEN c.qtd_pontos_validos < 2 THEN NULL
         ELSE CAST(s.taxa_r2_aulas AS DECIMAL(18,6)) END AS taxa_r2_aulas,
    CASE WHEN c.qtd_pontos_validos < 2 THEN NULL
         ELSE CAST(s.taxa_slope_tempo AS DECIMAL(18,6)) END AS taxa_slope_tempo,
    CASE WHEN c.qtd_pontos_validos < 2 THEN NULL
         ELSE CAST(s.taxa_r2_tempo AS DECIMAL(18,6)) END AS taxa_r2_tempo
FROM contagem_pontos c
LEFT JOIN slope_calc s ON c.aluno_id = s.aluno_id
ORDER BY c.aluno_id;

-- COMMAND ----------
-- V2: celula 28 (indice zero) do DBC original.
CREATE OR REPLACE TEMP VIEW v3_v2_abt_engajamento_aluno AS
WITH base_alunos AS (
    SELECT aluno_id FROM v3_v2_metrica_cadastro
    UNION
    SELECT aluno_id FROM v3_v2_metrica_acessos
    UNION
    SELECT aluno_id FROM v3_v2_metrica_recencia
    UNION
    SELECT aluno_id FROM v3_v2_metrica_frequencia
    UNION
    SELECT aluno_id FROM v3_v2_metrica_progresso_velocidade
    UNION
    SELECT aluno_id FROM v3_v2_metrica_cursos
    UNION
    SELECT aluno_id FROM v3_v2_metrica_historico
    UNION
    SELECT aluno_id FROM v3_v2_evolucao_mensal_slope
)
SELECT
    b.aluno_id,
    cd.data_cadastro,
    cd.dias_cadastro,
    ac.numero_acessos_dias_distintos AS numero_acessos,
    ac.taxa_aproveit_acessos,
    r.recencia AS recencia_dias,
    f.frequencia_media_dias AS media_intervalo_acessos_dias,
    pv.progresso AS progresso_pct,
    pv.velocidade AS velocidade_pct_dia,
    c.cursos_concluidos,
    c.cursos_andamento,
    h.tendencia_acessos AS historico_acessos,
    h.r2_hist_acessos AS r2_historico_acessos,
    s.taxa_slope_cursos,
    s.taxa_slope_aulas,
    s.taxa_slope_tempo AS taxa_slope_horas,
    s.taxa_r2_cursos,
    s.taxa_r2_aulas,
    s.taxa_r2_tempo AS taxa_r2_horas
FROM base_alunos b
LEFT JOIN v3_v2_metrica_cadastro cd ON b.aluno_id = cd.aluno_id
LEFT JOIN v3_v2_metrica_acessos ac ON b.aluno_id = ac.aluno_id
LEFT JOIN v3_v2_metrica_recencia r ON b.aluno_id = r.aluno_id
LEFT JOIN v3_v2_metrica_frequencia f ON b.aluno_id = f.aluno_id
LEFT JOIN v3_v2_metrica_progresso_velocidade pv ON b.aluno_id = pv.aluno_id
LEFT JOIN v3_v2_metrica_cursos c ON b.aluno_id = c.aluno_id
LEFT JOIN v3_v2_metrica_historico h ON b.aluno_id = h.aluno_id
LEFT JOIN v3_v2_evolucao_mensal_slope s ON b.aluno_id = s.aluno_id
ORDER BY b.aluno_id;
-- COMMAND ----------
-- 4. V1 EXPERIMENTAL (celulas 24-26): separado do score.
-- Correcoes: duracao por aritmetica (o unix_timestamp original tratava-a como data),
-- matriculas deduplicadas por aluno+curso, safra consolidada em MIN por aluno.
-- Nao e reproducao bit a bit das saidas salvas desses experimentos.
CREATE OR REPLACE TEMP VIEW v3_v1_exp_cursos AS
SELECT a.aluno_id,a.curso_id,MIN(a.cadastro_data) cadastro_data,
       SUM(d.duracao_segundos) duracao_curso_segundos
FROM (SELECT aluno_id,curso_id,MIN(cadastro_data) cadastro_data
      FROM v3_v2_alunos_geral WHERE status='Matrícula ativa'
      AND titulo_curso <> 'Happy Hour' GROUP BY aluno_id,curso_id) a
JOIN v3_v2_asn_aulas_duracao d ON a.curso_id=d.curso_id
WHERE d.curso <> 'Happy Hour' GROUP BY a.aluno_id,a.curso_id;

CREATE OR REPLACE TEMP VIEW v3_v1_exp_base AS
SELECT p.*,a.cadastro_data,d.duracao_segundos,
       CASE WHEN p.tempo_aula RLIKE '^[0-9]+:[0-5][0-9]:[0-5][0-9]$'
            AND d.duracao_segundos IS NOT NULL THEN LEAST(
           TRY_CAST(SPLIT_PART(p.tempo_aula,':',1) AS BIGINT)*3600
           + TRY_CAST(SPLIT_PART(p.tempo_aula,':',2) AS BIGINT)*60
           + TRY_CAST(SPLIT_PART(p.tempo_aula,':',3) AS BIGINT),
           d.duracao_segundos) END tempo_limitado_segundos
FROM v3_v2_progresso_total p
JOIN v3_v1_exp_cursos a ON p.aluno_id=a.aluno_id AND p.curso_id=a.curso_id
JOIN v3_v2_asn_aulas_duracao d ON p.curso_id=d.curso_id
 AND p.modulo_id=d.modulo_id AND p.aula_id=d.aula_id
WHERE d.curso <> 'Happy Hour';

CREATE OR REPLACE TEMP VIEW v3_v1_exp_mensal AS
SELECT aluno_id,DATE_FORMAT(data_conclusao,'yyyy-MM') mes_atividade,
       COUNT(DISTINCT curso_id) qtd_cursos_tocados_no_mes,
       COUNT(DISTINCT modulo_id) qtd_modulos_iniciados,
       COUNT(DISTINCT aula_id) qtd_aulas_vistas_no_mes,
       SUM(tempo_limitado_segundos) tempo_assistido_no_mes_seg
FROM v3_v1_exp_base WHERE data_conclusao IS NOT NULL
GROUP BY aluno_id,DATE_FORMAT(data_conclusao,'yyyy-MM');

CREATE OR REPLACE TEMP VIEW v3_v1_experimentos AS
WITH meta AS (
 SELECT aluno_id,COUNT(*) qtd_cursos_matriculados,
        SUM(duracao_curso_segundos) tempo_total_esperado_plataforma_seg,
        MIN(cadastro_data) cadastro_data
 FROM v3_v1_exp_cursos GROUP BY aluno_id
), esforco AS (
 SELECT aluno_id,SUM(tempo_limitado_segundos) tempo_assistido_global_seg,
        MIN(CAST(data_conclusao AS DATE)) primeiro_acesso,
        MIN(DATE_FORMAT(data_conclusao,'yyyy-MM')) safra_aluno,
        COUNT(DISTINCT CASE WHEN data_conclusao IS NOT NULL THEN curso_id END) qtd_cursos_iniciados,
        COUNT(DISTINCT CASE WHEN data_conclusao IS NOT NULL THEN modulo_id END) qtd_modulos_iniciados,
        COUNT(DISTINCT CASE WHEN data_conclusao IS NOT NULL THEN aula_id END) qtd_aulas_iniciadas
 FROM v3_v1_exp_base GROUP BY aluno_id
), calculo AS (
 SELECT m.*,e.safra_aluno,e.qtd_cursos_iniciados,e.qtd_modulos_iniciados,e.qtd_aulas_iniciadas,
        COALESCE(e.tempo_assistido_global_seg,0) tempo_assistido_global_seg,
        ROUND(COALESCE(e.tempo_assistido_global_seg,0)*100.0
             /NULLIF(m.tempo_total_esperado_plataforma_seg,0),2) progresso_plataforma_pct,
        CASE WHEN e.primeiro_acesso IS NOT NULL
             THEN GREATEST(DATEDIFF(c.data_fim,e.primeiro_acesso),1) END dias_primeiro_acesso,
        GREATEST(DATEDIFF(c.data_fim,m.cadastro_data),1) dias_matricula
 FROM meta m LEFT JOIN esforco e ON m.aluno_id=e.aluno_id CROSS JOIN v3_cfg c
)
SELECT *, CASE WHEN dias_primeiro_acesso IS NOT NULL
               THEN ROUND(progresso_plataforma_pct/dias_primeiro_acesso,4)
               ELSE 0 END velocidade_progresso_global,
          progresso_plataforma_pct progresso_medio_global_pct,
          ROUND(progresso_plataforma_pct/dias_matricula,4) velocidade_global_engajamento
FROM calculo;

-- COMMAND ----------
-- 5. QUALIDADE POR ALUNO: diagnosticos nao sao novas notas de engajamento.
CREATE OR REPLACE TEMP VIEW v3_qualidade_aluno AS
SELECT p.aluno_id,COUNT(*) qtd_registros_aula,
       COUNT_IF(d.aula_id IS NULL) qtd_registros_sem_duracao,
       COUNT_IF(p.data_conclusao IS NULL) qtd_registros_sem_data_conclusao,
       COUNT_IF(p.ultima_visualizacao IS NULL) qtd_registros_sem_ultima_visualizacao,
       COUNT_IF(CAST(p.ultima_visualizacao AS DATE)>c.data_fim
                OR CAST(p.data_conclusao AS DATE)>c.data_fim) qtd_registros_apos_corte
FROM v3_v2_progresso_total p CROSS JOIN v3_cfg c
LEFT JOIN v3_v2_asn_aulas_duracao d ON p.curso_id=d.curso_id AND p.aula_id=d.aula_id
GROUP BY p.aluno_id;

-- COMMAND ----------
-- 6. SAIDA: UMA LINHA POR ALUNO. Universo amplo da V1 + flag de elegibilidade V2.
-- Para reproduzir o publico V2: WHERE elegivel_v2 = TRUE.
-- V2 NULL em inelegiveis significa fora do universo; nao preencher tudo com zero.
CREATE OR REPLACE TEMP VIEW vw_abt_v3_aluno AS
WITH spine AS (SELECT DISTINCT aluno_id FROM v3_v2_alunos_geral WHERE aluno_id IS NOT NULL)
SELECT s.aluno_id,c.data_inicio,c.data_fim AS data_referencia,c.versao_regra,
       c.tamanho_periodo,c.percentual_minimo_assistido,
       (u.aluno_id IS NOT NULL) elegivel_v2,
       (COALESCE(q.qtd_registros_aula,0)>0) tem_registro_aula,
       COALESCE(q.qtd_registros_aula,0) qtd_registros_aula,
       COALESCE(q.qtd_registros_sem_duracao,0) qtd_registros_sem_duracao,
       COALESCE(q.qtd_registros_sem_data_conclusao,0) qtd_registros_sem_data_conclusao,
       COALESCE(q.qtd_registros_sem_ultima_visualizacao,0) qtd_registros_sem_ultima_visualizacao,
       COALESCE(q.qtd_registros_apos_corte,0) qtd_registros_apos_corte,
       a.Frequencia_Dias AS frequencia_dias_v1,
       a.velocidade_progresso AS velocidade_progresso_v1,
       a.progresso_plataforma_absoluto AS progresso_plataforma_absoluto_v1,
       a.qtd_cursos_ativos AS qtd_cursos_ativos_v1,
       a.dias_de_casa AS dias_de_casa_v1,
       a.profundidade_total_segundos AS profundidade_total_segundos_v1,
       a.Dias_Recencia AS dias_recencia_v1,
       a.qtd_aula_revistas AS qtd_aula_revistas_v1,
       a.frequencia AS frequencia_v1,
       a.progresso AS progresso_v1,
       a.profundidade AS profundidade_v1,
       a.recencia AS recencia_v1,
       a.revisao AS revisao_v1,
       a.frequencia_pr AS frequencia_pr_v1,
       a.progresso_pr AS progresso_pr_v1,
       a.profundidade_pr AS profundidade_pr_v1,
       a.recencia_pr AS recencia_pr_v1,
       a.revisao_pr AS revisao_pr_v1,
       a.frequencia_peso AS frequencia_peso_v1,
       a.progresso_peso AS progresso_peso_v1,
       a.profundidade_peso AS profundidade_peso_v1,
       a.recencia_peso AS recencia_peso_v1,
       a.revisao_peso AS revisao_peso_v1,
       a.score_classificao AS score_classificao_v1,
       a.classificao_ordinal AS classificao_ordinal_v1,
       a.profundidade_total_segundos/60.0 profundidade_total_minutos_v1,
       b.data_cadastro AS data_cadastro_v2,
       b.dias_cadastro AS dias_cadastro_v2,
       b.numero_acessos AS numero_acessos_v2,
       b.taxa_aproveit_acessos AS taxa_aproveit_acessos_v2,
       b.recencia_dias AS recencia_dias_v2,
       b.media_intervalo_acessos_dias AS media_intervalo_acessos_dias_v2,
       b.progresso_pct AS progresso_pct_v2,
       b.velocidade_pct_dia AS velocidade_pct_dia_v2,
       b.cursos_concluidos AS cursos_concluidos_v2,
       b.cursos_andamento AS cursos_andamento_v2,
       b.historico_acessos AS historico_acessos_v2,
       b.r2_historico_acessos AS r2_historico_acessos_v2,
       b.taxa_slope_cursos AS taxa_slope_cursos_v2,
       b.taxa_slope_aulas AS taxa_slope_aulas_v2,
       b.taxa_slope_horas AS taxa_slope_horas_v2,
       b.taxa_r2_cursos AS taxa_r2_cursos_v2,
       b.taxa_r2_aulas AS taxa_r2_aulas_v2,
       b.taxa_r2_horas AS taxa_r2_horas_v2,
       e.qtd_cursos_matriculados AS qtd_cursos_matriculados_v1_exp,
       e.tempo_total_esperado_plataforma_seg AS tempo_total_esperado_plataforma_seg_v1_exp,
       e.tempo_assistido_global_seg AS tempo_assistido_global_seg_v1_exp,
       e.progresso_plataforma_pct AS progresso_plataforma_pct_v1_exp,
       e.velocidade_progresso_global AS velocidade_progresso_global_v1_exp,
       e.safra_aluno AS safra_aluno_v1_exp,
       e.qtd_cursos_iniciados AS qtd_cursos_iniciados_v1_exp,
       e.qtd_modulos_iniciados AS qtd_modulos_iniciados_v1_exp,
       e.qtd_aulas_iniciadas AS qtd_aulas_iniciadas_v1_exp,
       e.progresso_medio_global_pct AS progresso_medio_global_pct_v1_exp,
       e.velocidade_global_engajamento AS velocidade_global_engajamento_v1_exp
FROM spine s CROSS JOIN v3_cfg c
LEFT JOIN v3_v1_resultado_grupo a ON CAST(s.aluno_id AS STRING)=a.aluno
LEFT JOIN v3_v2_abt_engajamento_aluno b ON s.aluno_id=b.aluno_id
LEFT JOIN v3_v2_alunos_geral_filtrado u ON s.aluno_id=u.aluno_id
LEFT JOIN v3_v1_experimentos e ON s.aluno_id=e.aluno_id
LEFT JOIN v3_qualidade_aluno q ON s.aluno_id=q.aluno_id;

-- Ponto de extensao: adicione novas metricas numa view por aluno e faca LEFT JOIN
-- aqui. Nunca junte aluno x mes/aula diretamente sem agregar primeiro.
SELECT * FROM vw_abt_v3_aluno ORDER BY aluno_id;
