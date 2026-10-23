"""Verificação local da tradução; não substitui execução no Databricks.

Uso: python scripts/validar_sql_local.py --pasta PASTA_MATERIAIS --saida resultado.json
Requer pandas, numpy, openpyxl, duckdb e sqlglot. Somente resultados agregados.
DuckDB recebe adaptações explícitas de funções Databricks. O percentil local
usa posto ceil(n*p), não o sketch distribuído do PERCENTILE_APPROX do Spark.
"""
from pathlib import Path
import argparse
import json
import math
import sys
import numpy as np
import pandas as pd

# Pasta opcional de dependências, sem alterar ambiente global.
parser = argparse.ArgumentParser()
parser.add_argument('--pasta',type=Path,required=True)
parser.add_argument('--deps',type=Path)
parser.add_argument('--saida',type=Path,required=True)
args = parser.parse_args()
if args.deps:
    sys.path.insert(0,str(args.deps))
import duckdb
import sqlglot
from sqlglot import exp

repo=Path(__file__).resolve().parents[1]
sql=(repo/'abt/sql/00_abt_engajamento_grupo.sql').read_text(encoding='utf-8')
parsed=sqlglot.parse(sql.replace("SET TIME ZONE 'UTC';",''),read='databricks')
checks=sqlglot.parse((repo/'abt/sql/01_validar_abt.sql').read_text(encoding='utf-8'),read='databricks')
assert all(x is not None for x in parsed+checks)
con=duckdb.connect()
con.execute("SET TimeZone='UTC'")
con.execute('CREATE MACRO GET(a,i) AS list_extract(a,i+1)')
con.execute('CREATE MACRO TRY_TO_TIMESTAMP(x) AS TRY_CAST(x AS TIMESTAMP)')
con.execute('''CREATE MACRO LOCAL_PERCENTILE(x,p) AS [
list_extract(list_sort(list(x)),cast(ceil(count(x)*0.25) AS INTEGER)),
list_extract(list_sort(list(x)),cast(ceil(count(x)*0.75) AS INTEGER))]''')
names=['alunos_geral','progresso','progresso_total']
data={n:pd.read_csv(args.pasta/(n+'.csv'),dtype=str) for n in names}
data['tempo_aula']=pd.read_excel(args.pasta/'tempo_aula.xlsx',dtype=str)
for n,df in data.items():
    con.register(n,df)
for query in parsed:
    if isinstance(query, exp.Create) and query.kind == 'VIEW':
        converted=query.sql(dialect='duckdb')
        converted=converted.replace('APPROX_QUANTILE(', 'LOCAL_PERCENTILE(')
        if query.this.name == 'abt_cfg':
            converted="CREATE OR REPLACE TEMP VIEW abt_cfg AS SELECT DATE '2026-01-26' AS data_referencia"
        con.execute(converted)
actual=con.sql('SELECT * FROM abt_resultado_grupo ORDER BY aluno').df().set_index('aluno')

def seconds(s):
    pieces=s.fillna('').str.split(':',expand=True).reindex(columns=range(3))
    return sum(pd.to_numeric(pieces[k],errors='coerce').fillna(0)*factor for k,factor in enumerate([3600,60,1]))

a=data['alunos_geral']; p=data['progresso']; t=data['progresso_total']; d=data['tempo_aula']
t=t.assign(seg=seconds(t.tempo_aula),dia=pd.to_datetime(t.ultima_visualizacao,utc=True).dt.tz_localize(None).dt.normalize())
expected=pd.DataFrame(index=sorted(a.aluno_id.unique()))
expected['Frequencia_Dias']=t[t.seg>=180].groupby('aluno_id').dia.nunique()
b=p.merge(a[['matricula_id','status','cadastro_data']],on='matricula_id')
b=b[(b.status=='Matrícula ativa') & (b.curso_titulo!='Comece por aqui')].copy()
b['seg']=seconds(b.carga_horaria); b['prog']=pd.to_numeric(b.progresso)
den=b.groupby('aluno_id').agg(qtd=('curso_id','nunique'),cadastro=('cadastro_data','min'))
pc=b.groupby(['aluno_id','curso_id']).agg(seg=('seg','max'),prog=('prog','max'))
num=pc[pc.seg>=600].groupby('aluno_id').prog.sum()
ref=pd.Timestamp('2026-01-26')
days=(ref-pd.to_datetime(den.cadastro)).dt.days.clip(lower=1)
expected['velocidade_progresso']=num.reindex(den.index).fillna(0)/den.qtd/days
expected['profundidade_total_segundos']=t.groupby('aluno_id').seg.sum()
r=p.merge(a[['matricula_id','cadastro_data']],on='matricula_id')
date=pd.to_datetime(r.ultimo_acesso,errors='coerce',utc=True).dt.tz_localize(None)
r['date']=date.fillna(pd.to_datetime(r.cadastro_data)).dt.normalize()
expected['Dias_Recencia']=(ref-r.groupby('aluno_id').date.max()).dt.days
dt=d.assign(oficial=seconds(d.Tempo))
rv=t.merge(dt[['curso_id','modulo_id','aula_id','oficial']],on=['curso_id','modulo_id','aula_id'],how='left')
expected['qtd_aula_revistas']=rv[rv.seg>rv.oficial.fillna(0)].groupby('aluno_id').aula_id.nunique()
expected=expected.fillna(0)
mapping=[('Frequencia_Dias','frequencia',.2),('velocidade_progresso','progresso',.2),
         ('profundidade_total_segundos','profundidade',.1),('Dias_Recencia','recencia',.4),('qtd_aula_revistas','revisao',.1)]
np.testing.assert_allclose(actual[[x[0] for x in mapping]],expected[[x[0] for x in mapping]],rtol=1e-10,atol=1e-10)
expected['score_classificao']=0.
for raw,label,weight in mapping:
    # Categorias são verificadas a partir dos números SQL já reconciliados:
    # evita que erro de arredondamento entre motores desfaça um empate no corte.
    s=actual[raw]; vals=sorted(s)
    q25=vals[math.ceil(len(vals)*.25)-1]; q75=vals[math.ceil(len(vals)*.75)-1]
    inv=label=='recencia'
    expected[label]=np.where(s<=q25,'Alto' if inv else 'Baixo',np.where(s>=q75,'Baixo' if inv else 'Alto','Medio'))
    z=(s.mean()-s if inv else s-s.mean())/s.std(ddof=1)
    expected[label+'_pr']=z
    expected['score_classificao']+=z*weight
score=expected.score_classificao
expected['classificao_ordinal']=np.select([expected.recencia.eq('Baixo'),score<=-1.5,score<=-.5,score<=.5,score<=1.5,score>1.5],
    ['Alto Risco','Alto Risco','Em Risco','Parcial','Acima da Média','Engajado'],default='Não Classificado')
numeric=[x[0] for x in mapping]+[x[1]+'_pr' for x in mapping]+['score_classificao']
np.testing.assert_allclose(actual[numeric],expected[numeric],rtol=1e-10,atol=1e-10)
for c in [x[1] for x in mapping]+['classificao_ordinal']:
    assert actual[c].tolist()==expected[c].tolist(),c
assert len(actual)==73 and actual.index.is_unique
assert actual.loc[actual.recencia.eq('Baixo'),'classificao_ordinal'].eq('Alto Risco').all()
failures=con.execute(checks[0].sql(dialect='duckdb')).df()
assert failures.falhas.sum()==0,failures
# Caso degenerado: uma linha, variância amostral nula; saída não deve inventar nota.
fixture=pd.DataFrame({'aluno':['fixture'],'data_referencia':[ref.date()], 'Frequencia_Dias':[1],
    'velocidade_progresso':[0.], 'profundidade_total_segundos':[180], 'Dias_Recencia':[1], 'qtd_aula_revistas':[0]})
con.register('abt_metricas_fixture',fixture)
con.execute('CREATE OR REPLACE TEMP VIEW abt_metricas_grupo AS SELECT * FROM abt_metricas_fixture')
edge=con.execute('SELECT score_classificao,classificao_ordinal FROM abt_resultado_grupo').fetchone()
assert edge[0] is None and edge[1]=='Não Classificado',edge
report={'status':'PASS','fonte':'Arquivos locais; corte 2026-01-26 UTC',
        'motor':'DuckDB com tradução sqlglot e adaptadores explícitos',
        'statements_parseados':len(parsed)+len(checks),'alunos_comparados':len(actual),
        'campos_numericos_comparados':numeric,'tolerancia_absoluta':1e-10,
        'categorias_comparadas':6,'checagens_sql_falhas':int(failures.falhas.sum()),
        'caso_variancia_nula':'PASS: score NULL, Não Classificado',
        'distribuicao_local':actual.classificao_ordinal.value_counts().to_dict(),
        'limite':'Não executado no Databricks. Percentis locais por posto, sem simular sketch distribuído. Não comprova paridade com saídas históricas do PySpark nem permissões/CTAS Delta.'}
args.saida.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=True))
