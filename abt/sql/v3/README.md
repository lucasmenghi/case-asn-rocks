# ABT v3 — base de homologação em SQL

A saída é **`vw_abt_v3_aluno`**, com **uma linha por aluno e 68 colunas**. Junta as métricas existentes de V1 e V2 sem escolher silenciosamente uma regra vencedora. Métricas novas podem entrar depois da homologação.

- **V1:** `abt/00_engajamento.ipynb` (inclusive os experimentos das células 24–26).
- **V2:** `ABT_Metricas_Aluno.dbc`, versão mais atual informada por Lucas. O código foi extraído do DBC original, com 77 células.
- **V3:** esta implementação, ainda em homologação; não foi executada no Databricks.

## Arquivos e execução

1. Abra [00_abt_v3.sql](00_abt_v3.sql) como notebook SQL no Databricks.
2. Ajuste os **seis FROM dos adaptadores no início** para o catálogo/schema da sua bronze. `case_asn.bronze` é uma suposição de configuração, não uma conexão verificada.
3. Confira os parâmetros em `v3_cfg`: início 18/11/2025, corte 26/01/2026, período de 10 dias e mínimo assistido de 5%, iguais aos defaults da V2. O corte descreve os dados históricos; a entrega do projeto é 11/11/2026.
4. Execute todos os blocos na ordem e na **mesma sessão**. São 40 TEMP VIEWs, sem CREATE TABLE, INSERT, escrita Delta ou mudança das fontes. As views desaparecem quando a sessão termina; o script permite recriá-las. Para conectar um relatório em outra sessão, será necessário publicar depois views comuns em um schema definido.
5. Execute [01_homologar_abt_v3.sql](01_homologar_abt_v3.sql) na mesma sessão. Investigue qualquer falha antes de usar o relatório.
6. Use [DICIONARIO.md](DICIONARIO.md) para homologar cada coluna. O score V1 é mantido para comparação; não é um novo score da V3.

```sql
SELECT * FROM vw_abt_v3_aluno ORDER BY aluno_id;
-- Público comparável ao universo da V2:
SELECT * FROM vw_abt_v3_aluno WHERE elegivel_v2;
-- Comparar um caso individual:
SELECT * FROM vw_abt_v3_aluno WHERE aluno_id = 1086;
```

## Fontes necessárias

| Adaptador / fonte proposta | Colunas utilizadas |
|---|---|
| alunos_geral | aluno_id, curso_id, matricula_id, status, titulo_curso, cadastro, cadastro_data |
| progresso | aluno_id, curso_id, matricula_id, curso_titulo, progresso, ultimo_acesso, carga_horaria |
| progresso_total | aluno_id, curso_id, modulo_id, aula_id, ultima_visualizacao, data_conclusao, tempo_aula |
| usuarios_geral | aluno_id, data_cadastro |
| tempo_aula — dimensão manual V1 | curso_id, modulo_id, aula_id, Tempo |
| asn_aulas_duracao — dimensão completa V2 | curso_id, modulo_id, aula_id, curso, duracao_segundos, duracao_hhmmss |

**A dimensão completa não está entre os arquivos locais recebidos.** Ela já é referenciada pelas duas versões nos volumes do Databricks; sua existência atual não foi consultada. Se houver somente o CSV no Volume, substitua o FROM desse adaptador por `read_files` com o caminho correto e tipagem adequada. Isso continua sendo leitura por view. Não substitua automaticamente essa dimensão pela planilha manual: a cobertura é diferente. Sem a dimensão completa, as métricas dependentes não estão prontas para homologação numérica.

## Como as versões convivem

| Família | Conteúdo |
|---|---|
| `*_v1` | Cinco dimensões brutas, progresso absoluto, intermediários, categorias, Z-scores, pesos, score e classificação |
| `*_v2` | 18 colunas de cadastro, presença/aproveitamento, progresso, cursos e tendências |
| `*_v1_exp` | Safra, volumes, carga, progresso global e duas velocidades experimentais |
| Sem sufixo | Identificador, parâmetros, elegibilidade e diagnósticos |

O universo principal contém os IDs de alunos_geral, como a V1. A flag `elegivel_v2` reproduz a exclusão do aluno 466 e de quem só possui o curso 96. Assim você consegue inspecionar inclusive os alunos excluídos da V2; as colunas V2 ficam NULL para eles. Isso não prova pagamento: não há informação financeira nessas fontes.

O histórico mensal fica em views próprias, preservando o grão aluno×mês. Não é unido diretamente à saída por aluno, pois isso duplicaria suas linhas. As views mensais também ficam disponíveis para conferir os pontos que formam cada slope.

## Ajustes e limites explícitos

- V1 principal reaproveita a tradução SQL já existente, com tipagem numérica, menor data de matrícula determinística e proteção para desvio zero. Acrescenta os intermediários da célula 18 e a profundidade em minutos.
- V2 mantém as fórmulas e os diferentes tratamentos de janela/nulo. O filtro de matrícula ativa usa EXISTS para evitar multiplicar consumo por matrículas duplicadas; o denominador do progresso usa cursos ativos distintos por aluno. Esses ajustes podem diferir de resultados antigos com duplicidade.
- O adaptador de usuários agrupa por aluno e adota a menor data de cadastro. Chaves duplicadas na dimensão de duração precisam ser corrigidas na fonte: o SQL de homologação sinaliza o problema, sem escolher arbitrariamente uma duração.
- Experimentos V1 usam segundos por aritmética, em lugar do unix_timestamp sobre uma duração. Deduplicam matrícula por aluno+curso e consolidam safra por aluno. Por isso, são traduções corrigidas, não reprodução literal de saídas antigas. O restante da regra de Happy Hour e as diferentes velocidades permanece explícito.
- V1 preserva a regra legada que considera duração manual ausente como zero na revisão. Essa coluna pode sugerir revisão indevidamente; homologar antes de usar.
- As datas são normalizadas em TIMESTAMP_NTZ nos adaptadores para preservar o relógio da V2; a sessão fica em UTC. Não há conversão automática para São Paulo. Confirmar a semântica da origem antes de alterar o fuso.
- O corte não filtra retroativamente consumo acumulado. Se houver dados posteriores, obtenha uma extração correspondente ao corte ou adote um corte compatível; não basta apagar linhas após a data para reconstruir o histórico.
- Os dias disponíveis são inferidos a partir de duas datas por aula. Não temos log de cada acesso nem distribuição diária do tempo acumulado. As séries mensais atribuem o consumo a data_conclusao, como no original.
- R² mede ajuste da regressão, não confiança estatística, causalidade ou qualidade de aprendizagem.

## Validação local

[validacao_local.json](validacao_local.json) registra o smoke test: parser Databricks e execução adaptada em DuckDB, com 73 alunos únicos, 62 elegíveis V2 e 68 colunas. Foram verificados preservação de alunos sem acesso, elegibilidade, limites da taxa, consultas de homologação, matrícula duplicada e denominador zero.

A dimensão manual parcial foi usada **somente como fixture no teste**, para exercitar os joins. A consulta de qualidade identificou uma duração inválida nessa fixture; o alerta está registrado no JSON, sem ser tratado como aprovação dos dados. Isso não certifica os números da V2. Percentis locais usam posto e não reproduzem o sketch do Spark. Sintaxe, permissões e resultados no motor Databricks precisam ser conferidos no workspace. O teste local é reproduzível por `validar_local.py` usando duckdb/sqlglot da pasta analise_local/sql_deps, sem instalar bibliotecas globalmente.

Referências oficiais: [CREATE VIEW](https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-syntax-ddl-create-view), [REGR_SLOPE](https://docs.databricks.com/aws/en/sql/language-manual/functions/regr_slope).
