# Andamento e próximos passos

## O objetivo de negócio

Os materiais procuram transformar sinais de uso da plataforma em uma leitura do engajamento de alunos. A utilidade esperada é apoiar a professora/gestão na identificação de afastamento, orientar acompanhamento e entender a jornada de estudo.

Há duas frentes na apresentação `O Motor de Engajamento`: perguntas de negócio sobre jornada, onboarding e mentorias, e construção técnica de métricas/ABT. As perguntas sobre aprendizagem real, satisfação e impacto de intervenções precisam de dados adicionais. Tempo de vídeo e cliques medem comportamento observado; não comprovam aprendizagem nem efeito causal sobre abandono.

## O que já existe

| Etapa | Evidência | Situação verificável |
|---|---|---|
| Conhecimento dos dados | Dicionário Excel com perguntas e algumas respostas atribuídas à Dri | Levantamento inicial disponível; ainda há ambiguidades |
| Bases de trabalho | Quatro CSV e suas versões Excel, mais duração manual de aulas | Amostra local disponível |
| Cinco dimensões e score | Dois notebooks em `abt/`, documento da ABT e apresentação do motor | Código e saídas salvas disponíveis; regras divergentes |
| Safra e progresso global | Células 24–26 do notebook `00`, índices começando em zero | Experimentos disponíveis; não alimentam o score final desse notebook |
| Agrupamento de perfis | Notebook `01`, células 33–36 | K-Means com quatro grupos e saída de silhouette ≈ 0,5501; busca de K salva como cancelada |
| Oito conjuntos de métricas | Exportações `ABT_Metricas_Aluno` | Referência compartilhada por outro grupo; não é entrega do nosso grupo |
| ABT persistida e execução automática | No notebook `00`, escrita Delta está comentada | Não comprovadas no ambiente real |
| Tradução SQL do grupo | Pasta `abt/sql/`, publicada em 23/10/2026 | Métricas e score verificados localmente para 73 alunos; validação no Databricks pendente |
| Painel e processo de acompanhamento | Aparecem como finalidade/próximos passos | Não há entrega funcional comprovada nos materiais examinados |

Não há uma ata completa das aulas nem histórico confiável de quem fez cada parte. As datas de modificação dos arquivos recebidos também não permitem reconstruir a cronologia das decisões. O documento de métricas contém uma anotação de aula de 07/07/2026, mas isso não estabelece a data de cada trecho.

## Entrega de 7 de novembro

Lucas confirmou o escopo: **ABT com as métricas, um rascunho de dashboard para apresentação e um modelo de cronograma de trabalho com etapas e prazos estimados para cada atividade**. O desenvolvimento da ABT acontece no Databricks. Ainda falta definir a ferramenta do dashboard e os critérios de avaliação.

Como proposta inicial, o rascunho pode mostrar uma visão geral dos alunos elegíveis, distribuição das métricas, sinais de afastamento e uma tabela para explorar o perfil de cada aluno. Deve explicitar a data de corte e as definições dos indicadores. A escolha dos visuais depende das métricas que o grupo validar.

## Alinhamento do grupo informado em 23/10/2026

- O encontro foi dedicado à discussão e ao alinhamento, sem desenvolvimento prático. Por esse motivo, o grupo não considerou pertinente gravá-lo.
- Já existe bastante material produzido, mas falta padronização e consolidação.
- Thiago Nobrega trabalhará na versão final da ABT durante a semana, com base no que já montou.
- Lucas preparará uma versão para explorar e conhecer os dados e apoiar a discussão do grupo; ela não representa a ABT final consolidada.
- Próximo encontro: sexta-feira, às 20h. Interpretado como 30/10/2026 com base na data deste relato; Lucas não explicitou a data absoluta.
- No próximo encontro, a intenção é começar o desenvolvimento prático da primeira versão do painel.
- Além da ABT e do painel, é necessário entregar um modelo de cronograma de trabalho com etapas e prazos estimados para cada atividade.
- Lucas ainda não havia comunicado a Thiago a exigência do cronograma. O responsável por essa entrega e os prazos específicos ainda não foram definidos.

## O que precisa acontecer antes de avançar

A prioridade é fechar o contrato da ABT: **quais alunos entram, qual período ela descreve, o que cada métrica significa e qual decisão a demandante tomará com o resultado**. Depois, consolidar uma única implementação e validar casos concretos. Adicionar algoritmos antes disso manteria as mesmas ambiguidades em resultados mais difíceis de explicar.

A sequência abaixo é uma proposta anterior ao último alinhamento e precisa ser revista considerando o próximo encontro e a entrega adicional do cronograma. Não representa prazos acordados pelo grupo:

1. **Até 23/10:** confirmar critério de sucesso, universo e regras de métricas com a professora, e escolher a ferramenta do rascunho de dashboard. Distribuir responsáveis no grupo.
2. **Até 28/10:** obter a duração completa das aulas e a referência de validação do outro grupo. Consolidar a construção da ABT no Databricks e conferir unicidade, cobertura e datas.
3. **Até 02/11:** validar alunos sem acesso, alunos novos, acesso sem consumo, revisão e retorno após afastamento. Revisar indicadores com a demandante.
4. **Até 05/11:** preparar a ABT documentada e o rascunho de dashboard, com exemplos e limitações. Reservar 06/11 para ajustes e entregar em 07/11.

Essas datas são uma proposta de organização, sem compromissos atribuídos a integrantes. Thiago ficou responsável pela versão final da ABT e Lucas pela versão exploratória. A responsabilidade pelo cronograma, a ferramenta do dashboard e os critérios de avaliação seguem em aberto.

## Como organizar o grupo

Manter uma lista curta de tarefas, cada uma com responsável, prazo, evidência e condição para considerar pronta. Uma divisão possível é dados/qualidade, métricas/ABT, validação de negócio e apresentação. As definições devem ficar neste repositório para que todos trabalhem com as mesmas regras.

## Pendências externas

- Confirmar critérios de avaliação da ABT e do rascunho de dashboard de 7/11, além da ferramenta para o painel.
- Obter o conteúdo falado do vídeo para complementar a passagem de contexto.
- Obter `asn_aulas_duracao.csv`, que é lido pelos notebooks, mas não foi recebido na pasta.
- Obter o notebook `Proj EAD - Dicionário de Dados`, citado pela referência externa, mas ausente.
- Confirmar qual notebook do Databricks corresponde à versão atual do nosso grupo.
