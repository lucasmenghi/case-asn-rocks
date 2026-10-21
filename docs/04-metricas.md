# Métricas e diferenças entre versões

As versões respondem a perguntas parecidas com definições diferentes. O refinamento recebido do outro grupo é uma referência útil, mas a escolha das regras ainda precisa ser assumida e validada pelo nosso grupo com a demandante.

## As cinco dimensões do nosso protótipo

Referência de código: `abt/00_engajamento.ipynb`; números de células abaixo começam em zero. O notebook `01` repete a construção básica e acrescenta clusters.

| Dimensão | Pergunta | O que o código efetivamente calcula |
|---|---|---|
| Frequência | Em quantos dias aparece estudando? | Dias distintos de `ultima_visualizacao` em linhas com tempo assistido ≥ 180 segundos (célula 13) |
| Progresso | Com que ritmo avança? | Soma do maior progresso por curso com consumo ≥ 600 segundos, dividida pela quantidade de cursos ativos válidos; depois divide pelos dias desde `cadastro_data`. Exclui `Comece por aqui` (célula 18) |
| Profundidade | Quanto tempo dedicou? | Soma de `tempo_aula` convertido em segundos, com uma coluna adicional em minutos (célula 29) |
| Revisão | Há sinal de repetição do conteúdo? | Quantidade de aulas distintas cujo tempo assistido supera a duração oficial (célula 34) |
| Recência | Há quantos dias deixou de acessar? | Dias entre `current_date()` e o maior último acesso de curso, usando cadastro da matrícula quando o acesso está ausente (célula 37) |

Esses sinais são aproximações. A frequência não captura dias intermediários entre primeira e última interação da mesma aula. Tempo maior que a duração sugere repetição, mas também pode refletir funcionamento do player ou problemas de medição.

### Como o score funciona

Na célula 40, cada métrica é colocada em escala comparável:

`z = (valor do aluno − média da base) / desvio padrão da base`

Na recência, o sinal é invertido, porque mais dias de ausência deve reduzir a nota:

`z_recencia = (média da base − dias de ausência) / desvio padrão`

O score soma `20% frequência + 20% progresso + 10% profundidade + 40% recência + 10% revisão`, usando os Z-scores. Ele não representa probabilidade de abandono e não é uma nota de 0 a 100.

Antes do score, as métricas também recebem rótulos por percentis 25 e 75. Na recência, menos dias significa rótulo melhor. Empates podem fazer os grupos terem tamanhos diferentes de 25%/50%/25%.

| Condição, em ordem de prioridade | Classificação |
|---|---|
| Rótulo de recência `Baixo` | Alto Risco, independentemente do score |
| Score ≤ −1,5 | Alto Risco |
| −1,5 < score ≤ −0,5 | Em Risco |
| −0,5 < score ≤ 0,5 | Parcial |
| 0,5 < score ≤ 1,5 | Acima da Média |
| Score > 1,5 | Engajado |

Os pesos e cortes são regras propostas. Não foi localizada validação contra abandono observado. A soma ponderada de Z-scores não tem necessariamente distribuição normal nem desvio padrão igual a 1. Por isso os cortes não garantem percentuais fixos de alunos por classificação.

### Os experimentos novos ainda não substituem a fórmula antiga

As células 24–26 de `00` calculam alternativas por tempo útil de aula, progresso global, safra de primeiro acesso e evolução mensal. A meta usa a carga horária dos cursos matriculados. A célula 25 chama o resultado de `progresso_medio_global_pct`, mas o código calcula razão entre somas de tempo, não média simples dos percentuais dos cursos.

A ABT final continua ligada a `dm_progresso`, da célula 18. Portanto, melhorar essas alternativas isoladamente ainda não altera o score final. Além disso, a célula 26 reatribui `tempo_aula` para o arquivo novo, que usa `duracao_hhmmss`; a revisão posterior procura a coluna `tempo` e possui erro salvo. É necessário consolidar as versões e executar em sessão limpa.

## A referência externa com oito conjuntos de métricas

Fonte: `ABT_Metricas_Aluno.dbc/.html`, outro grupo. Parâmetros padrão: início 18/11/2025, fim 26/01/2026, períodos de dez dias, consumo mínimo de 5% da duração para considerar uma aula assistida nas métricas aplicáveis.

| Conjunto | Significado e cálculo resumido | Colunas na ABT |
|---|---|---|
| Cadastro e tempo como aluno | Cadastro original em `usuarios_geral`; dias até o corte | `data_cadastro`, `dias_cadastro` |
| Acessos e aproveitamento | União das datas de última visualização e conclusão; dias aproveitados com pelo menos uma aula ≥ 5% / dias de acesso | `numero_acessos`, `taxa_aproveit_acessos` |
| Recência | Corte menos maior última visualização; sem acesso fica nulo | `recencia_dias` |
| Frequência média | Média dos intervalos entre datas distintas; exige pelo menos duas datas | `media_intervalo_acessos_dias` |
| Progresso e velocidade | Tempo útil limitado à duração / carga total matriculada × 100; dividido pelos dias desde o primeiro acesso válido | `progresso_pct`, `velocidade_pct_dia` |
| Cursos concluídos e em andamento | Concluído se consumo ≥ 75% da duração do curso; em andamento abaixo disso, mas com aula acima do mínimo de consumo | `cursos_concluidos`, `cursos_andamento` |
| Histórico de acessos | Inclinação da reta de quantidade de dias de acesso por período; R² da regressão | `historico_acessos`, `r2_historico_acessos` |
| Evolução mensal | Cursos distintos/dia, aulas distintas/dia e horas/dia; inclinação e R² dessas taxas mensais | `taxa_slope_cursos`, `taxa_slope_aulas`, `taxa_slope_horas`, `taxa_r2_cursos`, `taxa_r2_aulas`, `taxa_r2_horas` |

Somando o `aluno_id`, a seleção final tem 19 colunas. A numeração original das métricas (12, 05, 01, 02, 08, 11, 06 e 09) é preservada no notebook; a falta de números intermediários não significa falta de células no arquivo recebido.

Para progresso, conclusão e evolução mensal, o código externo exclui os cursos 29, 62 e 80, descritos como descontinuados, e 94, descrito como agenda. O progresso considera **toda a carga horária matriculada válida**, incluindo cursos não iniciados. Isso difere de um trecho do DOCX, que propõe somente os cursos iniciados.

## Como interpretar tendência

*Slope* é a inclinação de uma reta: positivo indica aumento, negativo indica redução. Sua unidade depende da métrica e do período escolhido. Mudar de períodos de dez dias para sete dias altera a comparação.

R² mede quanto da variação dos pontos é explicado pela reta. **R² alto não prova uma tendência futura nem confirma abandono.** Com dois pontos distintos, uma reta pode apresentar R² igual a 1 por construção. Séries curtas, meses omitidos e mudanças recentes exigem leitura conjunta com recência e volume.

A referência deixa meses sem acesso como nulos em parte da evolução mensal; a regressão não os trata como meses de esforço zero. Isso é uma decisão de modelagem que pode esconder uma parada. Além disso, atribuir o tempo acumulado da aula ao mês de `data_conclusao` não reconstrói necessariamente o tempo realmente assistido naquele mês.

## Regras que divergem e precisam de decisão

| Tema | Divergências encontradas |
|---|---|
| Consumo mínimo para frequência | Código GitHub e DOCX da ABT: 3 minutos. Apresentação: 1 minuto. DOCX de métricas: 60 segundos, seguido de anotação para retirar a regra. Referência externa: conta acesso sem esse filtro e calcula aproveitamento com mínimo de 5% |
| Significado de frequência | GitHub: número de dias, maior tende a ser melhor. Referência externa: intervalo médio, menor tende a ser melhor. Os sinais não podem ser usados no mesmo score sem adaptação |
| Progresso | Percentual informado pela plataforma; razão entre tempos; ou média dos percentuais dos cursos. São indicadores diferentes |
| Meta de progresso | Cursos ativos matriculados ou apenas cursos iniciados |
| Tempo de relacionamento | Cadastro original do usuário, cadastro de matrícula ou primeiro acesso |
| Sem acesso | Recência nula, dias desde cadastro ou zero automático. Zero na recência pode parecer acesso recente |
| Universo e tempo | 73 alunos e data corrente no GitHub; 62 alunos elegíveis e corte fixo na referência |

## O papel dos clusters

O K-Means do notebook `01` agrupa alunos pelas cinco métricas padronizadas, sem usar os pesos do score. A saída salva mostra quatro grupos com 39, 1, 6 e 27 alunos, totalizando 73, e silhouette de aproximadamente 0,5501. A tentativa posterior de testar K de 2 a 7 aparece cancelada.

Esses números são saídas históricas salvas, não uma nova execução. O grupo de um único aluno merece investigação como possível perfil extremo. O número do cluster é apenas um identificador; não significa ordem de risco. Nomear os perfis exige examinar suas métricas e validar sua utilidade com a demandante.
