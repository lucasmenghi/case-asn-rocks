# Mapa dos materiais

Inventário dos 17 arquivos originais recebidos. Os nomes foram preservados, inclusive a grafia `Enganjamento`. O [manifesto](inventario-fontes.json) contém tamanhos e hashes SHA-256 para identificar essas versões.

## Bases e dicionário

| Arquivo | O que contém e para que serve |
|---|---|
| `alunos_geral.csv` | 3.067 matrículas de 73 alunos. Define vínculo aluno–curso, status, datas e universo inicial da ABT |
| `alunos_geral.xlsx` | Versão em planilha das matrículas, com aba `alunos_geral` e `Tabela dinâmica 2`. Há diferenças de representação e duas linhas não vazias adicionais em relação ao CSV; não assumir intercambialidade |
| `usuarios_geral.csv` | 73 usuários, uma linha por aluno. Cadastro original, último acesso geral e poucos dados de perfil |
| `usuarios_geral.xlsx` | Versão em planilha com 73 linhas não vazias de dados. Ordem/representações diferem do CSV |
| `progresso.csv` | 3.067 registros por matrícula. Progresso agregado do curso, aulas acessadas, tempo e último acesso do curso |
| `progresso.xlsx` | Versão em planilha com 3.067 linhas não vazias de dados. Não comprovada equivalência célula a célula com o CSV |
| `progresso_total.csv` | 1.487 registros de 66 alunos em aulas. Fonte de datas e tempo assistido; não é um histórico completo de sessões |
| `progresso_total.xlsx` | Versão em planilha com 1.487 linhas não vazias de dados. Não comprovada equivalência célula a célula com o CSV |
| `tempo_aula.xlsx` | Dimensão manual com 206 aulas em 39 cursos, identificadores e coluna `Tempo`. Serve para comparar tempo assistido e duração oficial; não substitui automaticamente a dimensão completa de 749 aulas mencionada na referência |
| `Dicionário de dados.xlsx` | Abas `Tabelas`, `Cursos` e `Cursos-Aulas`. Descreve variáveis, exploração, dúvidas e algumas respostas da demandante. Há textos com acentuação corrompida e definições antigas a reconciliar |

As contagens dos CSV consideram registros, sem cabeçalho. As contagens Excel ignoram linhas inteiramente vazias. Os notebooks existentes leem **CSV**: usar esses arquivos como referência para explicar o código atual.

## Documentos e apresentações

| Arquivo | Função e estado do conteúdo |
|---|---|
| `Documentação da ABT_ Motor de Engajamento de Alunos.docx` | Descreve cinco dimensões, quartis, Z-score, pesos e classificação de risco. É especificação do motor, mas afirma conclusão que não foi comprovada pela revisão técnica |
| `Métricas de Engajamento para Aluno.docx` | Documento de trabalho com regras e anotações de revisão. Contém uma versão de progresso marcada como inválida e alternativas posteriores. Não é uma especificação única fechada |
| `O Motor de Engajamento.pptx` | Apresentação de 13 slides: negócio, cinco dimensões, score, semáforo, maturidade técnica e perguntas para a plataforma. Útil para explicar a proposta; não comprova implantação |
| `Métricas de Enganjamento ASN.pptx` | Apresentação de 12 slides. Os iniciais tratam de tipos de engajamento, amostra e diagrama de dados. A partir do slide 5 há conteúdo de template sobre vendas/Black Friday e placeholders; não tratar esses trechos como escopo do case |
| `Métricas de Enganjamento ASN.pptx.pdf` | PDF de 12 páginas da apresentação anterior. O texto extraído confirma a mesma estrutura e os mesmos resíduos de template. É versão de consulta, sem evidência de uma análise adicional |

## Referência de outro grupo

| Arquivo | Função |
|---|---|
| `ABT_Metricas_Aluno.dbc` | Arquivo Databricks importável, com 77 células SQL/Python/Markdown. Prepara bases, calcula oito conjuntos de métricas, reúne ABT, produz gráficos e interpreta exemplos |
| `ABT_Metricas_Aluno.html` | Exportação para leitura no navegador, com código e resultados incorporados. Os textos das 77 células são idênticos aos do DBC quando ordenados pelo campo `position` |

Lucas confirmou em 20/10/2026 que essa referência veio de outro grupo e é mais refinada. Sua autoria deve continuar explícita. Não há evidência de que tenha sido aprovada como implementação oficial da turma.

## Materiais que já estavam no GitHub

| Caminho | O que faz |
|---|---|
| [`abt/00_engajamento.ipynb`](../abt/00_engajamento.ipynb) | Carrega CSV, explora dados, cria cinco dimensões, experimenta progresso global/safra/evolução mensal, monta ABT e score. A versão final ainda usa `dm_progresso`, a primeira fórmula de progresso |
| [`abt/01_engajamento_clusters.ipynb`](../abt/01_engajamento_clusters.ipynb) | Repete o motor de cinco dimensões e aplica K-Means nas métricas padronizadas. Mostra perfis dos grupos e gráficos, com busca de K cancelada nas saídas salvas |

Esses notebooks foram analisados a partir do commit `fac420554803597827c3fdcc8f57285f9366b3f8`. A revisão preservou o código existente.

## Vídeo e fontes ausentes

O [vídeo compartilhado](https://www.youtube.com/watch?v=n2U7tZijzXs) tem duração informada de 13min27s e canal `thiago nobrega`. A página foi acessada, mas as legendas automáticas retornaram vazias em múltiplos formatos. Não houve análise do áudio ou das imagens do vídeo. Uma transcrição ou o arquivo de vídeo permitirá complementar a documentação.

Também faltam a dimensão `asn_aulas_duracao.csv` e o notebook `Proj EAD - Dicionário de Dados`. O Miro mencionado na apresentação não veio acompanhado de link ou exportação.
