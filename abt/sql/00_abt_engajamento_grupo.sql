-- Databricks notebook source
-- Tradução de abt/00_engajamento.ipynb, células 13,18,29,34,37,40 (índice zero).
-- Regras do GRUPO: cinco dimensões, dm_progresso original, Z-score e kill switch.
-- Não incorpora métricas do outro grupo, safra, progresso global ou K-Means.
-- Execute os comandos na ordem, na MESMA sessão de notebook/SQL.
-- CONFIGURAÇÃO: confirme catálogo.schema da bronze; altere USE abaixo se necessário.
-- Destinos: case_asn.gold.abt_engajamento_detalhada e case_asn.gold.abt_engajamento.

USE CATALOG case_asn;
USE SCHEMA bronze;
SET TIME ZONE 'UTC';

-- COMMAND ----------
-- Padrão fiel ao notebook: data corrente. Para reproduzir os CSV históricos,
-- substitua current_date() por DATE '2026-01-26'. Não é filtro de eventos:
-- dados posteriores ao corte devem ser removidos na fonte se usar outro corte.
CREATE OR REPLACE TEMP VIEW abt_cfg AS
SELECT current_date() AS data_referencia;

-- COMMAND ----------
-- Fontes: tabelas bronze com os nomes dos arquivos, sem extensão.
CREATE OR REPLACE TEMP VIEW abt_src_alunos AS
SELECT CAST(aluno_id AS STRING) AS aluno_id,
       CAST(matricula_id AS STRING) AS matricula_id,
       CAST(curso_id AS STRING) AS curso_id,
       CAST(status AS STRING) AS status,
       TRY_CAST(cadastro_data AS DATE) AS cadastro_data
FROM alunos_geral;

CREATE OR REPLACE TEMP VIEW abt_src_progresso AS
SELECT CAST(aluno_id AS STRING) AS aluno_id,
       CAST(matricula_id AS STRING) AS matricula_id,
       CAST(curso_id AS STRING) AS curso_id,
       CAST(curso_titulo AS STRING) AS curso_titulo,
       TRY_CAST(progresso AS DOUBLE) AS progresso,
       TRY_TO_TIMESTAMP(CAST(ultimo_acesso AS STRING)) AS ultimo_acesso_ts,
       COALESCE(TRY_CAST(GET(SPLIT(CAST(carga_horaria AS STRING), ':'), 0) AS BIGINT), 0) * 3600
       + COALESCE(TRY_CAST(GET(SPLIT(CAST(carga_horaria AS STRING), ':'), 1) AS BIGINT), 0) * 60
       + COALESCE(TRY_CAST(GET(SPLIT(CAST(carga_horaria AS STRING), ':'), 2) AS BIGINT), 0) AS carga_segundos
FROM progresso;

CREATE OR REPLACE TEMP VIEW abt_src_aulas AS
SELECT CAST(aluno_id AS STRING) AS aluno_id,
       CAST(curso_id AS STRING) AS curso_id,
       CAST(modulo_id AS STRING) AS modulo_id,
       CAST(aula_id AS STRING) AS aula_id,
       CAST(TRY_TO_TIMESTAMP(CAST(ultima_visualizacao AS STRING)) AS DATE) AS data_visualizacao,
       COALESCE(TRY_CAST(GET(SPLIT(CAST(tempo_aula AS STRING), ':'), 0) AS BIGINT), 0) * 3600
       + COALESCE(TRY_CAST(GET(SPLIT(CAST(tempo_aula AS STRING), ':'), 1) AS BIGINT), 0) * 60
       + COALESCE(TRY_CAST(GET(SPLIT(CAST(tempo_aula AS STRING), ':'), 2) AS BIGINT), 0) AS tempo_segundos
FROM progresso_total;

-- A dimensão manual do grupo possui Tempo (case-insensitive em SQL).
-- Se sua tabela usa duracao_hhmmss, ajuste APENAS esta projeção e valide cobertura.
CREATE OR REPLACE TEMP VIEW abt_src_duracao AS
SELECT CAST(curso_id AS STRING) AS curso_id,
       CAST(modulo_id AS STRING) AS modulo_id,
       CAST(aula_id AS STRING) AS aula_id,
       COALESCE(TRY_CAST(GET(SPLIT(CAST(Tempo AS STRING), ':'), 0) AS BIGINT), 0) * 3600
       + COALESCE(TRY_CAST(GET(SPLIT(CAST(Tempo AS STRING), ':'), 1) AS BIGINT), 0) * 60
       + COALESCE(TRY_CAST(GET(SPLIT(CAST(Tempo AS STRING), ':'), 2) AS BIGINT), 0) AS duracao_segundos
FROM tempo_aula;

-- COMMAND ----------
CREATE OR REPLACE TEMP VIEW abt_metricas_grupo AS
WITH frequencia AS (
    SELECT aluno_id, COUNT(DISTINCT data_visualizacao) AS Frequencia_Dias
    FROM abt_src_aulas WHERE tempo_segundos >= 180 GROUP BY aluno_id
), progresso_base AS (
    SELECT p.aluno_id, p.curso_id, a.cadastro_data, p.progresso, p.carga_segundos
    FROM abt_src_progresso p
    INNER JOIN abt_src_alunos a ON p.matricula_id = a.matricula_id
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
           / GREATEST(DATEDIFF(c.data_referencia, d.cadastro_data), 1) AS velocidade_progresso
    FROM progresso_denominador d
    LEFT JOIN progresso_numerador n ON d.aluno_id = n.aluno_id
    CROSS JOIN abt_cfg c
), profundidade AS (
    SELECT aluno_id, SUM(tempo_segundos) AS profundidade_total_segundos
    FROM abt_src_aulas GROUP BY aluno_id
), revisao AS (
    -- Preserva comportamento original: duração sem correspondência vira zero.
    -- Isso pode produzir falsa revisão: limitação registrada na documentação.
    SELECT p.aluno_id, COUNT(DISTINCT p.aula_id) AS qtd_aula_revistas
    FROM abt_src_aulas p
    LEFT JOIN abt_src_duracao d
      ON p.curso_id = d.curso_id AND p.modulo_id = d.modulo_id AND p.aula_id = d.aula_id
    WHERE p.tempo_segundos > COALESCE(d.duracao_segundos, 0)
    GROUP BY p.aluno_id
), recencia AS (
    SELECT p.aluno_id,
           DATEDIFF(c.data_referencia,
                    MAX(COALESCE(CAST(p.ultimo_acesso_ts AS DATE), a.cadastro_data))) AS Dias_Recencia
    FROM abt_src_progresso p
    INNER JOIN abt_src_alunos a ON p.matricula_id = a.matricula_id
    CROSS JOIN abt_cfg c
    GROUP BY p.aluno_id, c.data_referencia
), spine AS (
    -- Fiel à seleção original: todos os IDs de alunos_geral, sem excluir gratuitos/teste.
    SELECT DISTINCT aluno_id FROM abt_src_alunos
)
SELECT s.aluno_id AS aluno, c.data_referencia,
       COALESCE(f.Frequencia_Dias, 0) AS Frequencia_Dias,
       COALESCE(p.velocidade_progresso, 0.0) AS velocidade_progresso,
       COALESCE(d.profundidade_total_segundos, 0) AS profundidade_total_segundos,
       COALESCE(r.Dias_Recencia, 0) AS Dias_Recencia,
       COALESCE(v.qtd_aula_revistas, 0) AS qtd_aula_revistas
FROM spine s
CROSS JOIN abt_cfg c
LEFT JOIN frequencia f ON s.aluno_id = f.aluno_id
LEFT JOIN dm_progresso p ON s.aluno_id = p.aluno_id
LEFT JOIN profundidade d ON s.aluno_id = d.aluno_id
LEFT JOIN recencia r ON s.aluno_id = r.aluno_id
LEFT JOIN revisao v ON s.aluno_id = v.aluno_id;

-- COMMAND ----------
CREATE OR REPLACE TEMP VIEW abt_estatisticas_grupo AS
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
FROM abt_metricas_grupo;

-- COMMAND ----------
CREATE OR REPLACE TEMP VIEW abt_resultado_grupo AS
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
    FROM abt_metricas_grupo m CROSS JOIN abt_estatisticas_grupo e
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
-- Publicação SOMENTE das duas saídas geradas por este script. Não altera a bronze.
-- Para apenas inspecionar, execute SELECT * FROM abt_resultado_grupo e pare aqui.
CREATE SCHEMA IF NOT EXISTS case_asn.gold;

CREATE OR REPLACE TABLE case_asn.gold.abt_engajamento_detalhada USING DELTA AS
SELECT * FROM abt_resultado_grupo;

-- Interface de oito colunas, igual ao base_abt_save do grupo.
-- Grafia original dos nomes preservada para compatibilidade.
CREATE OR REPLACE TABLE case_asn.gold.abt_engajamento USING DELTA AS
SELECT aluno, frequencia, progresso, profundidade, recencia, revisao,
       score_classificao, classificao_ordinal
FROM case_asn.gold.abt_engajamento_detalhada;
