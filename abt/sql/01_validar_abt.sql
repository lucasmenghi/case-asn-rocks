-- Executar depois de 00_abt_engajamento_grupo.sql, na mesma sessão.
-- Todos os contadores de falhas devem ser zero. Não altera nenhuma tabela.
SELECT 'aluno_nulo' AS verificacao, COUNT(*) AS falhas
FROM abt_resultado_grupo WHERE aluno IS NULL
UNION ALL
SELECT 'aluno_duplicado', COUNT(*) FROM (
    SELECT aluno FROM abt_resultado_grupo GROUP BY aluno HAVING COUNT(*) <> 1
)
UNION ALL
SELECT 'aluno_fonte_ausente', COUNT(*) FROM (
    SELECT aluno_id FROM abt_src_alunos
    EXCEPT SELECT aluno FROM abt_resultado_grupo
)
UNION ALL
SELECT 'aluno_saida_extra', COUNT(*) FROM (
    SELECT aluno FROM abt_resultado_grupo
    EXCEPT SELECT aluno_id FROM abt_src_alunos
)
UNION ALL
SELECT 'score_nulo', COUNT(*) FROM abt_resultado_grupo WHERE score_classificao IS NULL
UNION ALL
SELECT 'kill_switch_nao_aplicado', COUNT(*) FROM abt_resultado_grupo
WHERE recencia = 'Baixo' AND classificao_ordinal <> 'Alto Risco'
UNION ALL
SELECT 'score_diferente_soma_pesos', COUNT(*) FROM abt_resultado_grupo
WHERE ABS(score_classificao - (frequencia_peso + progresso_peso + profundidade_peso
                              + recencia_peso + revisao_peso)) > 1e-10;

-- Diagnósticos: podem ser diferentes de zero; interpretar antes de aprovar a ABT.
SELECT 'matricula_duplicada' AS diagnostico, COUNT(*) AS ocorrencias FROM (
    SELECT matricula_id FROM abt_src_alunos GROUP BY matricula_id HAVING COUNT(*) > 1
)
UNION ALL
SELECT 'aluno_curso_multiplas_matriculas', COUNT(*) FROM (
    SELECT aluno_id, curso_id FROM abt_src_alunos GROUP BY aluno_id, curso_id HAVING COUNT(*) > 1
)
UNION ALL
SELECT 'aula_sem_duracao', COUNT(*)
FROM abt_src_aulas p LEFT JOIN abt_src_duracao d
ON p.curso_id = d.curso_id AND p.modulo_id = d.modulo_id AND p.aula_id = d.aula_id
WHERE d.aula_id IS NULL
UNION ALL
SELECT 'recencia_negativa', COUNT(*) FROM abt_resultado_grupo WHERE Dias_Recencia < 0;

SELECT classificao_ordinal, COUNT(*) AS alunos
FROM abt_resultado_grupo GROUP BY classificao_ordinal ORDER BY alunos DESC;

SELECT * FROM abt_estatisticas_grupo;
