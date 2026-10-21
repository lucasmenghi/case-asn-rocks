# Revisão técnica e dúvidas

Revisão estática dos arquivos e conferência dos CSV locais em 20/10/2026. Nenhum pipeline foi executado no Databricks. Os problemas abaixo são preexistentes e não foram corrigidos nesta etapa de documentação.

## Pontos do nosso código a resolver

| Evidência | Implicação | Próxima verificação |
|---|---|---|
| `00`, célula 40, ainda usa `dm_progresso` | Experimentos de progresso global e safra não alimentam o score | Escolher a definição e conectar uma implementação única |
| `00`, célula 26, reatribui `tempo_aula`; célula 34 espera `t.tempo` | Esquemas incompatíveis e `AnalysisException` salvo na revisão | Usar nomes distintos e alinhar a coluna de duração; executar do início em sessão limpa |
| Célula 40 seleciona todos os IDs sem filtro de status | A descrição “uma linha por aluno ativo” não está garantida fora da amostra atual | Criar lista explícita de elegíveis |
| Recência parte de join interno com `progresso` | O fallback não preserva aluno ausente dessa tabela | Partir da lista de alunos e conferir ausência de acesso |
| `.fillna(0)` na ABT | Dado ausente se mistura com ausência de consumo; recência zero parece boa | Definir tratamento por coluna |
| Conversão de duração usa `unix_timestamp(try_to_timestamp(...))` em experimentos | Uma duração é tratada como data/hora; o resultado depende das regras de parsing/runtime | Validar com casos de 30s, 1h e mais de 24h; preferir aritmética de duração |
| Sem proteção para desvio padrão zero no Z-score | Uma base pequena ou constante pode gerar divisão inválida | Definir fallback explícito para variáveis sem variação |
| Duplicidade aluno+curso nas matrículas | Join pode duplicar tempo e carga esperada | Deduplicar com regra de negócio antes do join |
| Revisão converte duração ausente/inválida em zero | Tempo positivo pode virar falsa evidência de revisão | Separar duração ausente de duração válida |
| `current_date()` com bases congeladas | Recência e velocidade mudam ao reexecutar sem mudança de comportamento | Usar corte fixo e salvar `data_referencia` |
| Escrita Delta comentada | Não há comprovação de publicação da tabela pelo notebook | Validar saída antes de habilitar persistência |

## Pontos da referência externa a validar antes de reaproveitar

O notebook é mais organizado na definição das métricas e no tratamento de dados insuficientes, mas não deve ser copiado como garantia de correção.

- **Janela temporal:** acessos aplicam `BETWEEN` com corte, mas outras métricas, como recência, frequência, progresso e evolução mensal, usam dados sem o mesmo filtro explícito. Na amostra atual a data final coincide com o último registro, mas mudar os widgets pode misturar janelas.
- **Pagantes:** a regra exclui quem só possui o curso 96 e o cadastro teste. Confirmar se esse critério representa os alunos desejados, inclusive outros conteúdos gratuitos e matrículas inativas.
- **Primeira interação:** a interpretação de `data_conclusao` como primeiro play aparece nos materiais, mas não foi comprovada por documentação técnica da plataforma. Tratar como hipótese até confirmação.
- **Histórico incompleto:** usar primeira e última data por aula não recupera dias intermediários. O indicador mede dias observáveis nesses campos, não todos os acessos reais.
- **Tempo mensal:** o tempo acumulado é atribuído ao mês da conclusão. Validar se essa aproximação serve para tendência mensal; seria necessário log de eventos para medir o tempo de cada mês com precisão.
- **Meses sem atividade:** nulos são ignorados pela regressão; avaliar junto com uma grade que represente explicitamente inatividade, quando houver cobertura dos dados.
- **R²:** duas observações podem gerar ajuste perfeito sem evidência robusta. Acrescentar quantidade de pontos e período observado à interpretação.
- **Fuso e datas:** `TIMESTAMP_NTZ` preserva relógio sem fuso. Validar qual data civil deve representar uma interação perto da meia-noite.
- **Dimensão e joins:** conferir unicidade de curso+aula, carga horária total, cobertura de aulas e duplicidades de matrícula. Os dois grupos não usam exatamente as mesmas chaves.
- **Ordem de execução:** o DBC guarda as células fora da ordem visual no array JSON. Sua sequência deve seguir `position`. Ainda assim, não houve execução limpa para verificar dependências, parâmetros e tabelas criadas.

## O que já está esclarecido

| Questão | Resposta / fonte |
|---|---|
| Onde o desenvolvimento acontece? | Databricks, informado por Lucas |
| De quem é `ABT_Metricas_Aluno`? | Outro grupo, compartilhado como referência refinada, informado por Lucas |
| Há decisões da última aula ausentes dos materiais? | Lucas informou que não |
| Qual o prazo? | `7/11`, informado por Lucas; 2026 inferido do contexto |
| A ABT externa preserva alunos sem acesso? | Sim, o código inclui a lista de elegíveis; métricas específicas ficam zero ou nulas |
| DBC e HTML são versões diferentes de código? | Os textos das 77 células são iguais após ordenar por `position` |

## O que ainda perguntar à demandante e ao grupo

1. Qual é o entregável de 7/11 e o critério de aceitação: ABT, apresentação, painel ou combinação?
2. Qual decisão será tomada a partir da ABT? Como reconhecer que o acompanhamento trouxe resultado?
3. Quem deve entrar: todos, somente pagantes, somente matrículas ativas ou uma safra específica?
4. Qual regra de acesso/consumo vale e quais campos representam primeiro play, conclusão e último acesso?
5. Progresso deve considerar toda a grade contratada ou somente cursos iniciados? Onboarding entra?
6. O objetivo imediato exige score único ou as métricas interpretáveis já atendem à demanda?
7. Quem fornece e mantém a duração completa das aulas? Onde está o notebook de validações citado pelo outro grupo?
8. Qual é o notebook atual no Databricks e quem responde por cada parte da entrega?

## Conferências mínimas para uma ABT pronta

Validar uma linha por aluno, cobertura do universo, ausência de multiplicação nos joins e coerência das unidades. Conferir progresso entre 0% e 100%, aproveitamento entre 0 e 1, recência não negativa e nulos explicados. Reexecutar com os mesmos dados e corte deve reproduzir o resultado.

Revisar casos de aluno sem acesso, com um único acesso, com matrícula duplicada, com consumo zero e check de conclusão, com duração ausente, com revisão e com afastamento após alto consumo histórico. Validar esses casos com a demandante antes de chamar o motor de concluído.
