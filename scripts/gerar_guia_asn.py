"""Gera o guia de leitura do case; reportlab, com fontes Arial do Windows."""
from pathlib import Path
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, Image, KeepTogether
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
import argparse

parser=argparse.ArgumentParser(); parser.add_argument('--saida',type=Path,required=True)
args=parser.parse_args(); args.saida.parent.mkdir(parents=True,exist_ok=True)
fonts=Path('C:/Windows/Fonts')
pdfmetrics.registerFont(TTFont('Arial',str(fonts/'arial.ttf')))
pdfmetrics.registerFont(TTFont('Arial-Bold',str(fonts/'arialbd.ttf')))
pdfmetrics.registerFont(TTFont('Arial-Italic',str(fonts/'ariali.ttf')))
pdfmetrics.registerFontFamily('Arial',normal='Arial',bold='Arial-Bold',italic='Arial-Italic',boldItalic='Arial-Bold')
navy=colors.HexColor('#173047'); teal=colors.HexColor('#087F8C'); gray=colors.HexColor('#536271')
styles=getSampleStyleSheet()
styles.add(ParagraphStyle(name='BodyASN',fontName='Arial',fontSize=10.6,leading=15.2,spaceAfter=9,textColor=navy))
styles.add(ParagraphStyle(name='TitleASN',fontName='Arial-Bold',fontSize=27,leading=32,spaceAfter=16,textColor=navy))
styles.add(ParagraphStyle(name='HASN',fontName='Arial-Bold',fontSize=17,leading=22,spaceAfter=13,textColor=navy))
styles.add(ParagraphStyle(name='SubASN',fontName='Arial-Bold',fontSize=11.4,leading=16,spaceBefore=8,spaceAfter=6,textColor=teal))
styles.add(ParagraphStyle(name='SmallASN',fontName='Arial',fontSize=9,leading=12.5,spaceAfter=7,textColor=gray))
styles.add(ParagraphStyle(name='CellASN',fontName='Arial',fontSize=9.2,leading=12.8,textColor=navy))
story=[]; width=A4[0]-104
def p(t,style='BodyASN'): return Paragraph(t,styles[style])
def add(t): story.append(p(t))
def sub(t): story.append(p(t,'SubASN'))
def page(k,title):
    if story: story.append(PageBreak())
    story.append(p(f'GUIA DE CONVERSA  /  {k:02d}','SmallASN'))
    story.append(p(title,'HASN'))
def table(headers,rows,widths):
    data=[[p('<b>'+v+'</b>','CellASN') for v in headers]]+[[p(str(v),'CellASN') for v in r] for r in rows]
    tab=Table(data,colWidths=[width*x for x in widths],hAlign='LEFT',repeatRows=1)
    tab.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#E5EEF2')),
        ('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.white,colors.HexColor('#F6F8FA')]),
        ('GRID',(0,0),(-1,-1),.4,colors.HexColor('#D4DFE6')),
        ('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),9),('RIGHTPADDING',(0,0),(-1,-1),9),
        ('TOPPADDING',(0,0),(-1,-1),8),('BOTTOMPADDING',(0,0),(-1,-1),8)]))
    story.extend([tab,Spacer(1,10)])
def box(t):
    tab=Table([[p(t)]],colWidths=[width]); tab.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),colors.HexColor('#EAF6F5')),('BOX',(0,0),(-1,-1),.5,colors.HexColor('#B4D8D4')),('LEFTPADDING',(0,0),(-1,-1),12),('RIGHTPADDING',(0,0),(-1,-1),12),('TOPPADDING',(0,0),(-1,-1),10),('BOTTOMPADDING',(0,0),(-1,-1),3)])); story.extend([tab,Spacer(1,10)])

page(1,'O projeto e o que você precisa dominar')
story.append(p('Case ASN Rocks','TitleASN'))
add('<b>Objetivo deste guia:</b> permitir que você explique o projeto, acompanhe as discussões do grupo e faça perguntas úteis sobre dados, métricas, ABT e dashboard. Leitura estimada: 20 a 25 minutos.')
box('<b>A fala de abertura:</b> “Estamos organizando os dados de uso da plataforma para entender o engajamento dos alunos. A ABT reúne uma linha por aluno e alimenta um rascunho de dashboard. Precisamos fechar as regras das métricas e validar os resultados antes de tratar o score como sinal confiável de afastamento.”')
sub('Qual é a demanda')
add('O curso simula um projeto real: a professora representa a demandante e os participantes trabalham em grupos. Os materiais apontam para acompanhamento dos alunos, identificação de afastamento e apoio a ações de retenção. O desenvolvimento acontece no <b>Databricks</b>.')
add('A entrega informada por você é em <b>7 de novembro de 2026</b>: <b>ABT com métricas e um rascunho de dashboard</b>. Critérios de avaliação e ferramenta do painel ainda não foram confirmados. Temos 15 dias corridos entre a revisão deste guia e a entrega.')
sub('O que já sabemos e o que ainda é proposta')
add('Seu grupo possui notebooks com cinco dimensões de engajamento, um score ponderado e uma experiência com clusters. Há uma versão mais refinada de outro grupo, compartilhada como referência. Ela não deve ser apresentada como trabalho já concluído pelo seu grupo.')
add('<b>A distinção central:</b> medir acesso e tempo de vídeo descreve uso observado. Não prova satisfação, aprendizagem ou abandono. O score atual é uma regra de priorização proposta, não uma probabilidade de churn validada.')
story.append(p('Atualizado em 23/10/2026. Baseado nos materiais locais, notebooks do repositório e esclarecimentos de Lucas. Não houve acesso ao workspace Databricks.','SmallASN'))

page(2,'As cinco bases sem confusão de granularidade')
add('<b>Granularidade</b> é o significado de uma linha. O erro mais fácil neste case é contar matrícula como pessoa ou registro de aula como sessão de estudo.')
table(['Base','Uma linha é...','Volume local'],[
('usuarios_geral','Uma pessoa cadastrada','73 alunos'),
('alunos_geral','Uma matrícula em um curso','3.067 matrículas / 73 alunos'),
('progresso','O resumo de progresso de uma matrícula','3.067 resumos'),
('progresso_total','O estado registrado de interação aluno-aula','1.487 registros / 66 alunos'),
('tempo_aula','Uma aula com duração de referência','206 aulas / 39 cursos')],[.28,.44,.28])
add('Um exemplo ilustrativo: a mesma pessoa pode ter uma linha em usuários, 50 matrículas, 50 resumos de progresso e 12 registros de aulas diferentes. Isso não significa 50 pessoas nem 12 sessões completas.')
sub('O papel de cada uma')
add('<b>usuarios_geral</b> preserva o cadastro original da conta. <b>alunos_geral</b> mostra o vínculo com os cursos. <b>progresso</b> fornece o avanço informado pela plataforma. <b>progresso_total</b> é a principal fonte de comportamento. <b>tempo_aula</b> permite comparar consumo com a duração esperada.')
sub('O que os números realmente dizem')
add('90,3% das matrículas têm progresso zero, mas <b>66 dos 73 alunos têm algum progresso positivo</b>. Um aluno possui muitos cursos disponíveis e pode concentrar estudo em poucos. Portanto, não podemos concluir que 90% da turma esteja inativa.')
add('Dos 73 alunos, sete não aparecem nos registros detalhados de aula. Entre os 66 que aparecem, 61 têm algum tempo assistido positivo. Essas três contagens representam cadastro, presença de registro e consumo, respectivamente.')
box('<b>Pergunta útil:</b> “O denominador desse indicador é aluno, matrícula ou aula? Estamos contando a mesma unidade antes de comparar?”')

page(3,'O desenho dos dados e a arquitetura no Databricks')
add('O slide 4 de <i>Métricas de Enganjamento ASN</i> contém o <b>Diagrama de Entidade e Relacionamento</b>. Ele foi examinado visualmente nesta revisão e mostra as quatro bases originais e suas chaves. A dimensão manual de duração complementa esse desenho.')
table(['Ligação','Como interpretar'],[
('Usuários → matrículas','aluno_id identifica a pessoa e seus vários vínculos.'),
('Matrículas → progresso','matricula_id conecta a matrícula ao seu resumo. Na amostra, há correspondência completa.'),
('Matrícula/curso → aulas','aluno_id + curso_id conecta o vínculo aos registros de aula. É preciso conferir duplicidade antes de somar.'),
('Duração → aulas','curso_id + modulo_id + aula_id conecta o tempo de referência ao tempo assistido.')],[.34,.66])
sub('Relacionamento de dados e camadas têm funções diferentes')
add('O diagrama explica <b>como as entidades se conectam</b>. Bronze, silver e gold explicam <b>em que estágio de preparação o dado está</b>. Seu upload na bronze é o ponto de partida, não a validação das métricas.')
table(['Camada','Função no case'],[
('Bronze','Guardar os dados recebidos, com rastreabilidade da origem.'),
('Silver','Preparar datas, duração em segundos, chaves e regras de duplicidade.'),
('Gold','Disponibilizar a ABT por aluno e os indicadores consumidos no dashboard.')],[.20,.80])
add('No Databricks, o nome completo segue <b>catálogo.schema.tabela</b>. A tradução SQL assume case_asn.bronze.alunos_geral. A ordem real ainda precisa ser confirmada no seu workspace; o início do script permite ajustar essa configuração.')
box('<b>Cuidado com o join:</b> se o resumo de um curso for repetido em cada aula e somado depois, o progresso será multiplicado. Calcule cada métrica no nível correto antes de reuni-las por aluno.')

page(4,'A ABT e as cinco dimensões do seu grupo')
add('<b>ABT</b> significa Analytical Base Table: a tabela analítica preparada para responder ao problema. Neste case, a saída tem <b>uma linha por aluno</b>, combinando diferentes sinais de engajamento.')
table(['Dimensão','Regra que alimenta a ABT final do grupo'],[
('Frequência','Conta dias distintos de última visualização em registros com pelo menos 180 segundos assistidos.'),
('Progresso / velocidade','Exclui Comece por aqui; soma o maior progresso por curso com consumo >= 600s; divide pelos cursos ativos e pelos dias desde cadastro da matrícula, mínimo de 1 dia.'),
('Profundidade','Soma todo o tempo assistido disponível, em segundos. É volume acumulado de dedicação registrada.'),
('Recência','Conta dias desde o maior último acesso a curso. Usa cadastro da matrícula como fallback e, depois, há preenchimento de métricas ausentes com zero.'),
('Revisão','Conta aulas distintas em que o tempo assistido supera a duração de referência. É uma aproximação de retorno/repetição.')],[.25,.75])
sub('Como a ABT é montada')
add('O código parte dos IDs distintos em alunos_geral, calcula as métricas em agregações separadas e faz LEFT JOIN. Isso preserva o universo fonte. A seleção final original guarda categorias, score e ordinal; a versão SQL também fornece uma tabela detalhada para auditoria.')
sub('A versão usada importa')
add('O notebook 00 contém experimentos de progresso por tempo útil, safra e evolução mensal. Porém a ABT final continua conectada ao <b>dm_progresso original</b>. Não basta existir uma célula mais nova: ela precisa alimentar efetivamente a saída.')
box('<b>Fala segura:</b> “Nossa ABT atual usa cinco dimensões. Temos alternativas de progresso em estudo, mas a saída final ainda usa a fórmula original. Vamos decidir qual definição responde melhor à demanda antes de trocar.”')

page(5,'Como funciona o score e o semáforo')
add('As métricas usam unidades diferentes: dias, segundos e percentual por dia. O grupo aplica <b>Z-score</b> para expressar quanto cada aluno está acima ou abaixo da média da base: <b>(valor - média) / desvio padrão</b>.')
add('Na recência, o sinal é invertido: menos dias de ausência deve melhorar o resultado. Um Z-score zero significa estar na média daquela métrica, não ausência de estudo.')
table(['Dimensão','Peso no score'],[('Recência','40%'),('Frequência','20%'),('Progresso / velocidade','20%'),('Profundidade','10%'),('Revisão','10%')],[.65,.35])
add('O score soma os Z-scores ponderados. <b>Não é nota de 0 a 100 nem probabilidade de abandono.</b> Os pesos refletem uma escolha de negócio ainda a validar.')
table(['Regra em ordem de prioridade','Classificação'],[
('Recência com rótulo Baixo','Alto Risco, independentemente do score'),
('Score <= -1,5','Alto Risco'),
('-1,5 < score <= -0,5','Em Risco'),
('-0,5 < score <= 0,5','Parcial'),
('0,5 < score <= 1,5','Acima da Média'),
('Score > 1,5','Engajado')],[.67,.33])
add('Os rótulos Alto/Medio/Baixo de cada dimensão usam os percentis 25 e 75. No caso da recência, a interpretação é inversa. Empates podem deixar os grupos com tamanhos diferentes dos quartis teóricos.')
box('<b>Exemplo ilustrativo:</b> um aluno que estudou muito no passado pode ter alto volume acumulado e estar ausente agora. A regra prioritária de recência existe para que seu histórico não esconda o afastamento atual.')

page(6,'Onde estamos e o que veio de outro grupo')
table(['Artefato','Estado que conseguimos comprovar'],[
('00_engajamento.ipynb','Exploração, cinco dimensões, score e experimentos. Há erro salvo na revisão e escrita Delta comentada.'),
('01_engajamento_clusters.ipynb','Repete a base e experimenta K-Means com quatro grupos. Saída salva: silhouette ~0,5501. Busca de K aparece cancelada.'),
('ABT_Metricas_Aluno.dbc / html','Referência refinada compartilhada por outro grupo, conforme sua confirmação. Não é a implementação do nosso grupo.'),
('Bronze','Você informou ter carregado as bases. Não houve conferência por acesso direto ao workspace.'),
('SQL do grupo','Tradução entregue com script de validação e instruções. Testada localmente; execução Databricks pendente.')],[.37,.63])
sub('O que a referência externa acrescenta')
add('Ela organiza oito conjuntos de métricas: cadastro, dias de acesso e aproveitamento, recência, intervalo médio entre acessos, progresso e velocidade, cursos concluídos/em andamento, tendência de acessos e evolução mensal de volume/tempo.')
add('Usa corte padrão em 26/01/2026 e uma regra de elegibilidade que seleciona 62 alunos como pagantes. Conta aproveitamento com consumo mínimo de 5% da duração e cursos concluídos a partir de 75%. Essas regras são diferentes das cinco dimensões do nosso motor.')
sub('Clusters e tendência são ferramentas diferentes')
add('<b>K-Means</b> agrupa perfis parecidos; o número do grupo não define risco. <b>Slope</b> descreve direção de uma reta ao longo do tempo. <b>R²</b> descreve aderência dos pontos à reta, sem provar comportamento futuro. Com dois pontos, ajuste perfeito pode ser apenas consequência matemática.')
add('Reaproveitar uma boa ideia exige entender sua definição, fonte e limite. Não precisamos somar todos os algoritmos para cumprir a entrega de ABT e rascunho de painel.')

page(7,'Os pontos que exigem senso crítico')
table(['Evidência local','O que muda na conversa'],[
('235 aulas com check de concluído e tempo zero','Não usar o check sozinho como aprendizagem ou consumo integral.'),
('28 tempos ausentes; 15 datas de conclusão ausentes','Separar zero medido de informação faltante.'),
('718 registros com tempo acima da duração manual','Revisão é uma hipótese; também pode haver repetição automática ou comportamento do contador.'),
('Um vínculo aluno+curso duplicado','Um join pode multiplicar dados mesmo sem linhas integralmente duplicadas.'),
('206 aulas na dimensão manual; todas as interações locais têm correspondência','Isso cobre as aulas observadas, não comprova o catálogo completo de cada curso.'),
('Datas detalhadas terminam em 26/01/2026','Usar a data de hoje sobre dados congelados muda recência sem mudança observada de comportamento.')],[.48,.52])
sub('Três datas que não são a mesma coisa')
add('O cadastro original da conta está em usuarios_geral. O cadastro da matrícula aparece em alunos_geral e se concentra em novembro de 2025. O primeiro acesso observável é outra data. A escolha muda velocidade, safra e interpretação de quem é “aluno novo”.')
sub('O limite do histórico de aulas')
add('Cada aluno-aula tem um registro nesta amostra. Primeira/conclusão e última visualização não revelam todos os dias intermediários. Atribuir todo o tempo acumulado ao mês da conclusão não mede com precisão as horas realmente estudadas naquele mês.')
box('<b>Pergunta útil:</b> “Esse indicador é medido diretamente ou depende de uma hipótese? Como ele se comporta para quem nunca acessou, para um aluno novo e para quem voltou depois de sumir?”')

page(8,'O que levar para a entrega de 7 de novembro')
add('A entrega combinada é <b>ABT com métricas e um rascunho de dashboard</b>. A sequência sugerida é fechar definições, validar a tabela e então desenhar a leitura gerencial.')
table(['Até quando','Resultado sugerido'],[
('23 a 26/10','Confirmar universo, data de referência, versão das métricas, ferramenta do painel e responsáveis.'),
('Até 28/10','Executar a ABT SQL em sessão limpa no Databricks; resolver fontes, tipos e cobertura.'),
('Até 02/11','Conferir casos concretos e validar interpretações com a professora.'),
('Até 05/11','Preparar a ABT documentada e o rascunho navegável ou estático de dashboard.'),
('06 e 07/11','Revisar números, limitações e narrativa; realizar a entrega.')],[.25,.75])
sub('Como pode ser a primeira versão do painel')
add('<b>Visão geral:</b> alunos elegíveis, alunos com registro e alunos com consumo positivo. <b>Leitura de engajamento:</b> distribuição de recência, frequência e progresso. <b>Investigação:</b> tabela por aluno com métricas e classificação, permitindo entender o motivo do sinal.')
add('Mostrar data de corte e definição do universo. Se o score for usado, explicar que é uma classificação por regra. Não apresentar “taxa de churn” sem definição e evento observado de abandono.')
sub('Quando considerar a ABT pronta para discutir')
add('Uma linha por aluno, cobertura do universo, joins sem multiplicação, unidades explícitas e nulos explicados. O score deve conferir com a soma dos pesos e a regra de recência deve prevalecer. Com mesmos dados e corte, o resultado deve ser reprodutível.')
box('<b>Casos mínimos de validação:</b> aluno sem acesso; um único acesso; consumo zero com check; matrícula duplicada; duração ausente; revisão; aluno novo; alto consumo histórico seguido de afastamento.')

page(9,'Como conversar com o grupo sem decorar jargão')
sub('Se perguntarem “qual é o problema de negócio?”')
add('“Queremos entender o uso da plataforma e identificar sinais de afastamento para apoiar o acompanhamento dos alunos. Estamos transformando dados de matrícula e aulas em uma visão por aluno.”')
sub('Se perguntarem “por que criar uma ABT?”')
add('“Porque as fontes têm níveis diferentes. A ABT consolida métricas na mesma granularidade, uma linha por aluno, para comparar perfis e alimentar o painel sem duplicar valores.”')
sub('Se alguém disser “90% não estudam”')
add('“Esse percentual é de matrículas com progresso zero. No nível de pessoa, 66 dos 73 alunos têm algum progresso. Precisamos manter o denominador correto.”')
sub('Se perguntarem “o motor já está pronto?”')
add('“Temos protótipo, regras e uma tradução SQL. Ainda precisamos validar a execução no Databricks e fechar divergências de definição. A documentação antiga de conclusão é mais forte do que as evidências técnicas disponíveis.”')
sub('Se sugerirem trocar tudo pela versão do outro grupo')
add('“Ela é uma referência útil e mais refinada, mas trabalha com outras definições e outro universo. Podemos aproveitar ideias depois de decidir o que queremos medir e deixar a autoria explícita.”')
sub('Se perguntarem “o que você consegue assumir agora?”')
add('“Posso ajudar a organizar as definições, conferir a ABT SQL contra os casos de teste e estruturar os indicadores do rascunho de dashboard. Precisamos nomear responsáveis e registrar o que foi aprovado.”')
box('<b>Quatro perguntas para uma reunião produtiva:</b><br/>1. Qual versão de regra vamos assumir?<br/>2. Qual decisão do negócio cada indicador apoia?<br/>3. Como validamos os casos que podem distorcer o resultado?<br/>4. Quem entrega o quê e em qual data?')

page(10,'Guia de execução do SQL e referências')
add('No repositório, abra <b>abt/sql/README.md</b>. A tradução principal está em <b>00_abt_engajamento_grupo.sql</b>; as conferências estão em <b>01_validar_abt.sql</b>. Execute as células na ordem, na mesma sessão.')
add('O início assume catálogo case_asn e schema bronze. Confirme essa ordem. A dimensão tempo_aula precisa da coluna Tempo em formato de duração. Ajuste a configuração de origem e a data de referência antes de executar.')
add('A versão detalhada é gravada em <b>case_asn.gold.abt_engajamento_detalhada</b>; a interface original de oito colunas em <b>case_asn.gold.abt_engajamento</b>. O bloco final substitui essas saídas. É possível parar antes dele e apenas inspecionar a view temporária.')
sub('O que foi testado e o que falta')
add('O teste local comparou as cinco métricas dos 73 alunos com cálculo independente, conferiu categorias e score e tratou variância nula. Usa DuckDB com adaptação de funções e percentil por posto. Isso não substitui execução limpa no Databricks nem prova igualdade com as saídas históricas do PySpark. Não foram testadas permissões ou escrita Delta no workspace.')
sub('Glossário para consulta rápida')
table(['Termo','Tradução prática'],[
('Spine','Lista inicial de alunos que deve existir na saída.'),
('Safra / cohort','Grupo definido por uma data de entrada que precisa ser especificada.'),
('Quartil','Posição relativa na distribuição; depende da população e dos empates.'),
('Z-score','Distância da média em unidades de desvio padrão.'),
('Churn','Abandono/cancelamento; exige evento ou definição operacional.'),
('Kill switch','Regra prioritária que sobrescreve a classificação pelo score.')],[.26,.74])
sub('Fontes e rastreabilidade')
story.append(p('Materiais locais: Dicionário de dados.xlsx; os quatro CSV e tempo_aula.xlsx; Documentação da ABT; Métricas de Engajamento para Aluno; O Motor de Engajamento; Métricas de Enganjamento ASN (slide 4). Código: abt/00_engajamento.ipynb e 01_engajamento_clusters.ipynb, versão fac4205; referência externa ABT_Metricas_Aluno.dbc/html. Contagens: análise local registrada em docs/06-analise-descritiva.md.','SmallASN'))
story.append(p('<link href="https://github.com/lucasmenghi/case-asn-rocks" color="#087F8C">Repositório: github.com/lucasmenghi/case-asn-rocks</link>. O vídeo do integrante permanece sem conteúdo falado incorporado: as tentativas de obter legendas retornaram vazias. As conclusões deste guia não foram atribuídas ao vídeo.','SmallASN'))

page(11,'Anexo visual do material original')
add('Este é o desenho de relacionamento que já estava no slide 4 da apresentação do grupo. A imagem foi extraída diretamente do arquivo original, sem redesenhar as ligações.')
asset=Path(__file__).resolve().parents[1]/'docs/assets/diagrama_original.png'
story.append(Image(str(asset),width=width,height=width*656/882))
story.append(Spacer(1,15))
story.append(p('Fonte: Métricas de Enganjamento ASN.pptx, slide 4, imagem incorporada ppt/media/image3.png. Diagrama produzido no dbdiagram.io e presente no material recebido.','SmallASN'))
sub('Como ler sem tirar conclusões além do desenho')
add('Leia primeiro a unidade de cada tabela e depois as chaves que conectam as entidades. O diagrama documenta a estrutura pretendida; a unicidade e a cardinalidade precisam ser conferidas nos dados reais. A dimensão manual tempo_aula, usada no cálculo de revisão, não aparece nesse desenho original.')
box('<b>Ao discutir o modelo:</b> “A estrutura original nos orienta, mas vamos validar a chave de cada join. Encontramos uma duplicidade de matrícula para o mesmo aluno e curso, então o desenho sozinho não evita multiplicação de linhas.”')

def footer(canvas,doc):
    canvas.saveState(); w,h=A4
    canvas.setStrokeColor(colors.HexColor('#D4DFE6')); canvas.line(52,42,w-52,42)
    canvas.setFont('Arial',8); canvas.setFillColor(gray)
    canvas.drawString(52,28,'ASN ROCKS  |  Guia de contexto  |  23/10/2026')
    canvas.drawRightString(w-52,28,str(doc.page)); canvas.restoreState()
doc=SimpleDocTemplate(str(args.saida),pagesize=A4,rightMargin=52,leftMargin=52,topMargin=42,bottomMargin=56,
    title='Case ASN Rocks - Guia de contexto e conversa',author='Lucas Menghi',subject='Projeto, dados, ABT, métricas e entrega de dashboard')
doc.build(story,onFirstPage=footer,onLaterPages=footer)
print(args.saida)
