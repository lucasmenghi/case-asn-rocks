-- Databricks notebook source
-- Execute APOS 00_abt_v3.sql, na MESMA sessao. Toda falha deve ser investigada.
CREATE OR REPLACE TEMP VIEW v3_homologacao AS
SELECT 'saida_aluno_duplicado' teste,COUNT(*) falhas FROM
 (SELECT aluno_id FROM vw_abt_v3_aluno GROUP BY aluno_id HAVING COUNT(*)>1)
UNION ALL SELECT 'saida_id_nulo',COUNT(*) FROM vw_abt_v3_aluno WHERE aluno_id IS NULL
UNION ALL SELECT 'aluno_fonte_ausente_na_saida',COUNT(*) FROM
 (SELECT DISTINCT aluno_id FROM v3_v2_alunos_geral WHERE aluno_id IS NOT NULL
  EXCEPT SELECT aluno_id FROM vw_abt_v3_aluno)
UNION ALL SELECT 'dim_completa_chave_curso_aula_duplicada',COUNT(*) FROM
 (SELECT curso_id,aula_id FROM v3_v2_asn_aulas_duracao GROUP BY curso_id,aula_id HAVING COUNT(*)>1)
UNION ALL SELECT 'dim_manual_chave_duplicada',COUNT(*) FROM
 (SELECT curso_id,modulo_id,aula_id FROM v3_src_duracao_manual GROUP BY curso_id,modulo_id,aula_id HAVING COUNT(*)>1)
UNION ALL SELECT 'dim_completa_duracao_invalida',COUNT(*) FROM v3_v2_asn_aulas_duracao
 WHERE duracao_segundos IS NULL OR duracao_segundos<=0
UNION ALL SELECT 'fonte_matricula_id_duplicada',COUNT(*) FROM
 (SELECT matricula_id FROM v3_v2_alunos_geral GROUP BY matricula_id HAVING COUNT(*)>1)
UNION ALL SELECT 'parametros_invalidos',COUNT(*) FROM v3_cfg
 WHERE data_inicio>data_fim OR tamanho_periodo<=0 OR percentual_minimo_assistido NOT BETWEEN 0 AND 1
UNION ALL SELECT 'eventos_apos_corte',COALESCE(SUM(qtd_registros_apos_corte),0) FROM vw_abt_v3_aluno
UNION ALL SELECT 'progresso_curso_apos_corte',COUNT(*) FROM v3_src_progresso CROSS JOIN v3_cfg
 WHERE TRY_CAST(ultimo_acesso AS DATE)>data_fim
UNION ALL SELECT 'taxa_aproveitamento_fora_0_1',COUNT(*) FROM vw_abt_v3_aluno
 WHERE taxa_aproveit_acessos_v2 NOT BETWEEN 0 AND 1
UNION ALL SELECT 'progresso_v2_fora_0_100',COUNT(*) FROM vw_abt_v3_aluno
 WHERE progresso_pct_v2 NOT BETWEEN 0 AND 100
UNION ALL SELECT 'recencia_v2_negativa',COUNT(*) FROM vw_abt_v3_aluno WHERE recencia_dias_v2<0
UNION ALL SELECT 'inelegivel_com_metrica_v2',COUNT(*) FROM vw_abt_v3_aluno
 WHERE NOT elegivel_v2 AND numero_acessos_v2 IS NOT NULL;

SELECT * FROM v3_homologacao ORDER BY teste;
-- Esperado: falhas=0. Cobertura abaixo e diagnostico, nao certificacao.
SELECT COUNT(*) alunos,COUNT_IF(elegivel_v2) elegiveis_v2,
       COUNT_IF(NOT tem_registro_aula) sem_registro_aula,
       COUNT_IF(qtd_registros_sem_duracao>0) alunos_sem_duracao_completa,
       COUNT_IF(progresso_pct_v2 IS NULL AND elegivel_v2) elegiveis_sem_progresso,
       COUNT_IF(score_classificao_v1 IS NULL) sem_score_v1
FROM vw_abt_v3_aluno;

-- Comparacao de regras: nao exigir igualdade entre metricas diferentes.
SELECT aluno_id,elegivel_v2,frequencia_dias_v1,numero_acessos_v2,
       dias_recencia_v1,recencia_dias_v2,
       progresso_plataforma_absoluto_v1,progresso_pct_v2,
       velocidade_progresso_v1,velocidade_pct_dia_v2,
       qtd_registros_sem_duracao,qtd_registros_sem_data_conclusao
FROM vw_abt_v3_aluno ORDER BY aluno_id;

-- Inspecao do nivel mensal, preservado em view separada.
SELECT v.aluno_id,v.mes_atividade,v.cursos_distintos_taxa,v.aulas_distintas_taxa,t.tempo_horas_taxa
FROM v3_v2_volume_final v LEFT JOIN v3_v2_tempo_final t
 ON v.aluno_id=t.aluno_id AND v.mes_atividade=t.mes_atividade
ORDER BY v.aluno_id,v.mes_atividade;
