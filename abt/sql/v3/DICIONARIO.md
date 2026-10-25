# Dicionário da ABT v3

Uma linha por aluno. As regras ainda precisam de homologação. Nomes históricos foram mantidos com sufixos para rastrear a origem.

## Contexto e qualidade

| Coluna | Significado |
|---|---|
| `aluno_id` | Identificador do aluno; universo de alunos_geral, sem ID nulo. |
| `data_inicio` | Início configurado para acessos/histórico/séries mensais V2; não filtra todas as métricas. |
| `data_referencia` | Corte histórico para idades e recência. Não é data da próxima entrega. |
| `versao_regra` | Identificação desta implementação para homologação. |
| `tamanho_periodo` | Tamanho do período de histórico V2, em dias (padrão 10). |
| `percentual_minimo_assistido` | Fração mínima da duração oficial para considerar aula assistida (padrão 0,05). |
| `elegivel_v2` | Falso para aluno 466 e para quem só tem curso 96. Aproximação de pagante, sem comprovação financeira. |
| `tem_registro_aula` | Existe alguma linha em progresso_total bruto; não comprova consumo. |
| `qtd_registros_aula` | Quantidade de linhas brutas de aula; não são necessariamente eventos. |
| `qtd_registros_sem_duracao` | Linhas sem correspondência curso+aula na dimensão completa. |
| `qtd_registros_sem_data_conclusao` | Linhas com data_conclusao ausente/inválida. |
| `qtd_registros_sem_ultima_visualizacao` | Linhas com ultima_visualizacao ausente/inválida. |
| `qtd_registros_apos_corte` | Linhas com alguma das datas após o corte. Se positivo, não interpretar como snapshot histórico. |

## V1 — métricas e score

| Coluna | Definição |
|---|---|
| `frequencia_dias_v1` | Dias distintos de última visualização com tempo acumulado da aula ≥180 segundos; não é contagem de sessões. |
| `velocidade_progresso_v1` | Média do progresso dos cursos dividida pelos dias desde o cadastro da matrícula (mínimo 1); exclui Comece por aqui; soma apenas cursos com carga ≥600s. |
| `progresso_plataforma_absoluto_v1` | Soma do maior progresso por aluno+curso com carga ≥600s / quantidade de cursos ativos distintos, exceto Comece por aqui. Escala herdada de progresso.progresso. |
| `qtd_cursos_ativos_v1` | Cursos ativos distintos usados no denominador da célula 18, excluindo Comece por aqui; inclui cursos abaixo de 600s. |
| `dias_de_casa_v1` | Dias entre corte e menor cadastro_data das matrículas da base de progresso; mínimo 1. |
| `profundidade_total_segundos_v1` | Soma do tempo acumulado assistido, sem limitar pela duração oficial; inclui repetições. |
| `dias_recencia_v1` | Dias desde maior último acesso de curso, com fallback no cadastro da matrícula; não usa a mesma fonte da recência V2. |
| `qtd_aula_revistas_v1` | Aulas distintas cujo tempo acumulado supera a duração manual; duração ausente vira zero na regra herdada, podendo gerar falsa revisão. |
| `frequencia_v1` | Categoria pelos percentis 25/75 de frequencia_dias no universo amplo da V1. |
| `progresso_v1` | Categoria pelos percentis 25/75 de velocidade_progresso, não do progresso absoluto. |
| `profundidade_v1` | Categoria pelos percentis 25/75 do tempo total assistido. |
| `recencia_v1` | Categoria invertida: menos dias é melhor; até P25 Alto, a partir de P75 Baixo. |
| `revisao_v1` | Categoria pelos percentis 25/75 da quantidade de aulas revistas. |
| `frequencia_pr_v1` | Z-score da dimensão (valor − média)/desvio amostral; recência tem sinal invertido. NULL quando desvio=0. |
| `progresso_pr_v1` | Z-score da dimensão (valor − média)/desvio amostral; recência tem sinal invertido. NULL quando desvio=0. |
| `profundidade_pr_v1` | Z-score da dimensão (valor − média)/desvio amostral; recência tem sinal invertido. NULL quando desvio=0. |
| `recencia_pr_v1` | Z-score da dimensão (valor − média)/desvio amostral; recência tem sinal invertido. NULL quando desvio=0. |
| `revisao_pr_v1` | Z-score da dimensão (valor − média)/desvio amostral; recência tem sinal invertido. NULL quando desvio=0. |
| `frequencia_peso_v1` | Z-score multiplicado pelo peso da dimensão no score legado. |
| `progresso_peso_v1` | Z-score multiplicado pelo peso da dimensão no score legado. |
| `profundidade_peso_v1` | Z-score multiplicado pelo peso da dimensão no score legado. |
| `recencia_peso_v1` | Z-score multiplicado pelo peso da dimensão no score legado. |
| `revisao_peso_v1` | Z-score multiplicado pelo peso da dimensão no score legado. |
| `score_classificao_v1` | Soma dos Z-scores ponderados: frequência 20%, progresso 20%, profundidade 10%, recência invertida 40%, revisão 10%. Não é probabilidade de evasão. |
| `classificao_ordinal_v1` | Recência Baixo força Alto Risco; demais cortes do score: -1,5 / -0,5 / 0,5 / 1,5. Regra legada não homologada. |
| `profundidade_total_minutos_v1` | Profundidade em segundos / 60. |

## V2 — cadastro e métricas

| Coluna | Definição |
|---|---|
| `data_cadastro_v2` | Cadastro original em usuarios_geral, reduzido a data. Adaptador usa MIN se a fonte trouxer duplicidade. |
| `dias_cadastro_v2` | Corte menos data_cadastro, sem +1. |
| `numero_acessos_v2` | Dias distintos da união de ultima_visualizacao e data_conclusao, dentro da janela individual. Uma aula tem no máximo essas duas datas disponíveis. |
| `taxa_aproveit_acessos_v2` | Dias de acesso com alguma aula cujo tempo/duração ≥5% / dias de acesso; escala 0–1; NULL sem acessos. O tempo é acumulado, não tempo comprovado naquele dia. |
| `recencia_dias_v2` | Corte menos maior ultima_visualizacao na base detalhada com matrícula ativa; NULL sem registro. Não aplica data_inicio. |
| `media_intervalo_acessos_dias_v2` | Média dos intervalos entre dias distintos da união das duas datas, em todo histórico filtrado; NULL com menos de 2 datas. Não aplica data_inicio. |
| `progresso_pct_v2` | 100 × soma do tempo por aluno+curso+aula limitado à duração / duração de todos os cursos ativos elegíveis. Exclui 94,29,62,80; depende da dimensão completa. |
| `velocidade_pct_dia_v2` | Progresso percentual / dias desde primeiro acesso histórico com duração conhecida, mínimo 1. Unidade: pontos percentuais/dia. |
| `cursos_concluidos_v2` | Cursos com tempo limitado assistido / duração total ≥75%. NULL sem base computável; zero com base sem curso concluído. Não representa certificado emitido. |
| `cursos_andamento_v2` | Cursos abaixo de 75% com pelo menos uma aula que atingiu 5% da duração. |
| `historico_acessos_v2` | REGR_SLOPE(dias de acesso por período, número do período). Inclui períodos sem acesso como zero. Unidade: dias de acesso/período adicional de 10 dias. |
| `r2_historico_acessos_v2` | R² da regressão de acessos; ajuste da reta, não confiança estatística nem prova de tendência futura. NULL sem dados suficientes. |
| `taxa_slope_cursos_v2` | Slope da taxa mensal de cursos distintos/dia disponível contra índice do mês. |
| `taxa_slope_aulas_v2` | Slope da taxa mensal de aulas distintas/dia disponível contra índice do mês. |
| `taxa_slope_horas_v2` | Slope da taxa mensal de horas/dia disponível contra índice do mês. |
| `taxa_r2_cursos_v2` | R² da série mensal de cursos/dia. Meses sem acesso são NULL e não entram na regressão. |
| `taxa_r2_aulas_v2` | R² da série mensal de aulas/dia. Requer ao menos dois pontos válidos. |
| `taxa_r2_horas_v2` | R² da série mensal de horas/dia. Série mensal usa data_conclusao; não distribui o tempo por dias reais. |

## V1 — experimentos das células 24–26

| Coluna | Definição |
|---|---|
| `qtd_cursos_matriculados_v1_exp` | Quantidade de cursos ativos com duração conhecida, exceto Happy Hour; deduplicado por aluno+curso. |
| `tempo_total_esperado_plataforma_seg_v1_exp` | Carga total dos cursos ativos conhecidos, exceto Happy Hour, em segundos. |
| `tempo_assistido_global_seg_v1_exp` | Soma do tempo limitado à duração oficial por registro aluno+aula; inválidos ficam NULL antes da soma. |
| `progresso_plataforma_pct_v1_exp` | 100 × tempo global limitado / carga total; arredondado a 2 casas. |
| `velocidade_progresso_global_v1_exp` | Progresso global / dias desde a menor data_conclusao, mínimo 1; arredondado a 4 casas. Zero se não há primeiro acesso. |
| `safra_aluno_v1_exp` | Menor mês de data_conclusao na base experimental elegível; não é safra de compra nem cadastro. |
| `qtd_cursos_iniciados_v1_exp` | Cursos distintos com data_conclusao preenchida na base experimental; nome histórico não comprova início real. |
| `qtd_modulos_iniciados_v1_exp` | Módulos distintos com data_conclusao preenchida; contagem pela chave modulo_id legada. |
| `qtd_aulas_iniciadas_v1_exp` | Aulas distintas com data_conclusao preenchida; contagem pela chave aula_id legada. |
| `progresso_medio_global_pct_v1_exp` | Mesmo percentual global da célula 25; mantido separado para rastrear o experimento. |
| `velocidade_global_engajamento_v1_exp` | Progresso global / dias desde a menor cadastro_data das matrículas elegíveis, mínimo 1; diferente do denominador da célula 24. |

## Janelas e valores ausentes

- V1: todo o histórico recebido; nulos das cinco métricas-base viram zero como no legado. Categorias e Z-scores usam todos os alunos V1, mesmo ao consultar somente elegíveis V2 depois.
- V2: cadastro, recência, intervalo, progresso e cursos usam o histórico disponível; acessos e séries usam janelas individuais. Não impor igualdade entre as versões.
- V2: em aluno inelegível, todas as colunas V2 são NULL; em elegível sem acesso, numero_acessos é 0 e taxa/recência/progresso ficam NULL conforme o legado.
- Mensal V2: mês sem registro de data_conclusao é NULL; mês com acesso mas sem consumo suficiente é 0. Regressões ignoram NULL; um R² alto com dois pontos não prova estabilidade.
- O mensal da V1 fica em v3_v1_exp_mensal e o da V2 em v3_v2_volume_final/v3_v2_tempo_final, separados da saída por aluno.
