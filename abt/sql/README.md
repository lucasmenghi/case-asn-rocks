# ABT do grupo em Databricks SQL

Tradução da ABT final de [`00_engajamento.ipynb`](../00_engajamento.ipynb), células 13, 18, 29, 34, 37 e 40, com índices começando em zero. A referência são as cinco dimensões que alimentam `base_abt_save`. Não incorpora os experimentos de safra/progresso global nem o trabalho do outro grupo. K-Means não faz parte desta tradução.

## Execução

1. Importe [`00_abt_engajamento_grupo.sql`](00_abt_engajamento_grupo.sql) como notebook SQL no Databricks ou execute os comandos na ordem, na mesma sessão.
2. Confira o início do arquivo. Ele assume **catálogo `case_asn`, schema `bronze`**. Se sua organização for catálogo `bronze`, schema `case_asn`, ajuste os dois `USE`. Os destinos `case_asn.gold.*` são explícitos e também devem ser ajustados caso esse catálogo não exista.
3. As fontes esperadas são `alunos_geral`, `progresso`, `progresso_total` e `tempo_aula`. A última precisa ter `curso_id`, `modulo_id`, `aula_id` e `Tempo`, com a duração em texto `HH:mm:ss`. `usuarios_geral` não entra no cálculo original do grupo. Não renomear silenciosamente `asn_aulas_duracao` para `tempo_aula`: os esquemas e coberturas podem diferir.
4. Escolha a data na view `abt_cfg`: `current_date()` reproduz o comportamento corrente do notebook; `DATE '2026-01-26'` é o corte usado no teste histórico. A data altera recência e velocidade, mas não filtra eventos. Usar outro corte com dados posteriores exige tratar a janela na origem.
5. Execute até `abt_resultado_grupo` para inspecionar sem persistência. O bloco final cria/substitui somente as duas tabelas de saída listadas abaixo; não altera a bronze.
6. Rode [`01_validar_abt.sql`](01_validar_abt.sql) na mesma sessão. Os contadores de falhas devem ser zero; investigue os diagnósticos, que podem ser positivos. Permissões de leitura e criação no destino são necessárias.

| Saída | Conteúdo |
|---|---|
| `case_asn.gold.abt_engajamento_detalhada` | Uma linha por aluno, data de referência, métricas brutas, categorias, Z-scores, pesos e resultado |
| `case_asn.gold.abt_engajamento` | As oito colunas originais de `base_abt_save`, com a grafia preservada |

## Correspondência de regras

| Etapa PySpark | Implementação SQL |
|---|---|
| `base_frequencia` | Dias distintos de última visualização com tempo assistido >= 180s |
| `dm_progresso` | Exclui Comece por aqui; cursos ativos distintos no denominador; maior progresso por curso só soma com carga >= 600s; divide pelos dias desde cadastro da matrícula, mínimo 1 |
| `base_profundidade` | Soma de tempo assistido em segundos |
| `base_revisao` | Aulas distintas com tempo assistido maior que duração manual |
| `base_recencia` | Corte menos maior último acesso de curso, com fallback de cadastro da matrícula |
| `base_abt` | Todos os alunos de alunos_geral, left joins, nulos das métricas convertidos em zero |
| `estatistica` | Percentis aproximados com accuracy 10000, média e desvio padrão amostral |
| Score | 20% frequência, 20% progresso, 10% profundidade, 40% recência invertida, 10% revisão |
| Ordinal | Kill switch de recência Baixo; depois cortes -1,5 / -0,5 / 0,5 / 1,5 |

## Ajustes técnicos explicitados

- **Duração manual nomeada:** o SQL lê diretamente a dimensão `tempo_aula`. Evita a reatribuição da variável Python para `asn_aulas_duracao` que causou erro no notebook, sem trocar a regra de revisão.
- **Tipagem:** chaves são normalizadas como texto; progresso vira DOUBLE antes de MAX. O CSV original era lido como texto, que pode comparar números lexicograficamente. Na amostra atual, os pares repetidos relevantes estão no onboarding excluído; validar novamente se a base mudar.
- **Datas:** leitura tolerante de timestamps e datas; fuso da sessão explicitado em UTC para reproduzir os arquivos locais. Confirmar o fuso do notebook original ao comparar resultados.
- **Data determinística por curso:** usa MIN de cadastro na agregação, evitando a escolha não determinística do `dropDuplicates`. Confirmar casos de múltiplas matrículas do mesmo curso em datas diferentes.
- **Desvio padrão zero:** `NULLIF` evita uma divisão por zero e mantém score nulo / Não Classificado quando cabível. O notebook não tinha proteção. Não imputa uma nota artificial para falta de variação.
- **Persistência e rastreabilidade:** adiciona tabela detalhada e data de referência; publica uma segunda tabela com a interface original. O notebook original tinha a escrita Delta comentada.

## Limitações preservadas para não mudar o negócio

O universo inclui gratuitos e cadastro de teste; somente o progresso filtra status ativo. Frequência e profundidade usam todo o histórico disponível. Recência ausente pode virar zero no preenchimento final. Duração sem correspondência vira zero e pode sugerir falsa revisão. A revisão não comprova aprendizagem. Os pesos/cortes são regras propostas, sem validação de churn observado. As versões divergentes dos documentos não foram adotadas como substitutas.

## Validação realizada em 23/10/2026

[`validacao_local.json`](validacao_local.json) registra PASS para 73 alunos no corte 26/01/2026 UTC. As cinco métricas foram comparadas com cálculo independente em pandas; Z-scores, score e categorias também foram conferidos, com tratamento explícito dos empates numéricos. As checagens de integridade retornaram zero falhas e um caso de variância nula preservou score ausente.

O teste executa uma tradução em DuckDB com adaptadores de funções; o percentil local usa posto `ceil(n*p)` e não simula o sketch distribuído do Spark. **Não houve execução no Databricks, nem comparação com uma execução limpa do notebook PySpark.** Sintaxe de configuração, permissões, escrita Delta e percentis do motor de destino ainda requerem a validação no workspace.

Para repetir: instale `pandas`, `numpy`, `openpyxl`, `duckdb` e `sqlglot` em um ambiente de teste e execute:

```text
python scripts/validar_sql_local.py --pasta "PASTA_DOS_MATERIAIS" --saida resultado.json
```

Referências de sintaxe: [percentile_approx](https://docs.databricks.com/gcp/en/sql/language-manual/functions/percentile_approx), [stddev_samp](https://docs.databricks.com/gcp/en/sql/language-manual/functions/stddev_samp) e [try_to_timestamp](https://docs.databricks.com/gcp/pt/sql/language-manual/functions/try_to_timestamp).
