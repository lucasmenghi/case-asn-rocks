# Dados e construção da ABT

## As tabelas em linguagem simples

**`usuarios_geral` é o cadastro da pessoa.** Tem 73 alunos únicos e a data original de cadastro na plataforma. Esse cadastro vai de 08/05/2024 a 28/11/2025.

**`alunos_geral` é o vínculo da pessoa com um curso.** Tem 3.067 matrículas e 73 alunos. Um aluno aparece várias vezes porque possui vários cursos. Todas as linhas do CSV estão como `Matrícula ativa`. A coluna `cadastro_data` contém datas de 18/11/2025 a 28/11/2025: ela descreve o cadastro da matrícula neste recorte, diferente do cadastro original do usuário.

**`progresso` resume cada matrícula.** Tem 3.067 registros e `matricula_id` único. Traz avanço do curso e último acesso; 2.753 linhas não têm último acesso preenchido.

**`progresso_total` detalha a interação aluno–aula.** Há 1.487 linhas, 66 alunos e nenhuma duplicação de aluno+aula na amostra. `log_id` coincide com `modulo_id` em todas as linhas e se repete: não é uma chave única de evento. As datas são campos de primeira/conclusão e última interação, com semântica ainda a confirmar. Não há lista completa de todos os plays de cada dia.

**`tempo_aula` descreve a duração oficial.** A planilha local contém 206 aulas em 39 cursos. Os códigos também dependem de uma dimensão completa chamada `asn_aulas_duracao.csv`, ausente da pasta. A referência externa informa 749 aulas em 47 cursos nessa outra dimensão; esses números foram lidos no notebook e não recalculados a partir do arquivo ausente.

## Relacionamentos

- `usuarios_geral.aluno_id` → matrículas de `alunos_geral`.
- `alunos_geral.matricula_id` → `progresso.matricula_id`.
- `alunos_geral.(aluno_id, curso_id)` → interações de `progresso_total`.
- `progresso_total.(curso_id, modulo_id, aula_id)` → duração da aula na dimensão manual. A referência externa usa curso+aula; validar unicidade antes de adotar essa chave.

Existe **um par aluno+curso com duas matrículas** no CSV. Um join nesse par pode multiplicar o consumo do aluno. O dicionário registra uma orientação atribuída à Dri: tratar a duplicidade gerada por curso gratuito seguido de matrícula paga, priorizando o registro com início preenchido. Isso precisa virar regra verificável antes das agregações; não aplicar uma exclusão manual sem conferir a fonte atual.

## O que significa montar a ABT

Escolher primeiro a lista de alunos que deve existir na saída, chamada de *spine*. Depois calcular cada métrica por aluno e fazer `LEFT JOIN` dessa lista com as métricas. Isso preserva quem não estudou — um caso importante para o problema de negócio.

| Decisão | Implementação do GitHub | Referência externa |
|---|---|---|
| Universo | IDs distintos de `alunos_geral`, sem filtro de status nessa seleção | Exclui aluno de teste e alunos matriculados apenas no curso gratuito 96 |
| Contagem na amostra | Universo fonte de 73 alunos | Regra reproduzida localmente seleciona 62 alunos |
| Sem interação detalhada | Métricas faltantes viram zero por `fillna(0)` | Número de acessos zero; diversas métricas ficam nulas |
| Data de referência | `current_date()` | Widget `data_fim`, padrão 26/01/2026 |
| Saída | Categorias, score e ordinal | 19 colunas: identificador e métricas interpretáveis |

Na regra externa, seis dos 62 alunos não têm linha em `progresso_total`. A regra usa matrícula fora do curso 96 como aproximação de pagante: não há transações financeiras na pasta que comprovem pagamento. O dicionário também menciona outros conteúdos gratuitos; confirmar o critério de elegibilidade.

## Limites observados da amostra

| Verificação local nos CSV | Resultado |
|---|---:|
| Alunos cadastrados | 73 |
| Alunos com registro detalhado de aula | 66 |
| Registros detalhados de aula | 1.487 |
| `tempo_aula` vazio/NA | 28 |
| `data_conclusao` vazia/NA | 15 |
| `aula_concluido = 1` com tempo `00:00:00` | 235 |
| Usuários sem UF | 68 |
| Matrículas com `inicio` vazio/NA | 2.749 |

Última visualização detalhada: **26/01/2026**. O último acesso geral do usuário e o último acesso do curso têm coberturas diferentes; não intercambiar os campos automaticamente.

Os 235 registros concluídos com tempo zero impedem interpretar o check de conclusão como evidência suficiente de consumo. A referência externa calcula conclusão por duração assistida, mas depende de uma dimensão de duração confiável.

## Cuidados para a próxima implementação

1. Registrar `data_referencia`, início da janela e versão das regras na saída.
2. Garantir uma linha por aluno no resultado e preservar alunos sem consumo.
3. Definir quando nulo significa dado insuficiente e quando zero significa comportamento medido como ausente.
4. Resolver duplicidade de matrícula e validar a cobertura da dimensão de aulas antes dos joins.
5. Converter duração `HH:mm:ss` por aritmética de horas/minutos/segundos, sem tratar duração como instante no calendário.
6. Fixar e testar a regra de fuso horário. A referência externa usa `TIMESTAMP_NTZ` para preservar o valor do relógio; isso não equivale, por si só, a converter UTC para horário de São Paulo.

Essas são recomendações para continuidade, não mudanças já executadas no Databricks.
