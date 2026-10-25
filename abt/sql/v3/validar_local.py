"""Smoke test local: parser Databricks + execucao adaptada em DuckDB.
A dimensao completa nao foi recebida; usa manual como FIXTURE de teste somente.
Nao certifica valores da V2 nem substitui execucao no Databricks.
"""
import sys,json,re,zipfile,xml.etree.ElementTree as ET
from pathlib import Path
base=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(base/'analise_local/sql_deps'))
import duckdb,sqlglot
from sqlglot import exp
folder=Path(__file__).resolve().parent
sql=(folder/'00_abt_v3.sql').read_text(encoding='utf8')
queries=sqlglot.parse(sql,read='databricks')
homologacao=sqlglot.parse((folder/'01_homologar_abt_v3.sql').read_text(encoding='utf8'),read='databricks')
assert not re.search(r'CREATE\s+(?:OR\s+REPLACE\s+)?TABLE\b',sql,re.I)
con=duckdb.connect()
con.execute('CREATE SCHEMA bronze')
con.execute('CREATE MACRO GET(a,i) AS list_extract(a,i+1)')
con.execute('CREATE MACRO TRY_TO_TIMESTAMP(x) AS TRY_CAST(x AS TIMESTAMP)')
con.execute('''CREATE MACRO LOCAL_PERCENTILE(x,p) AS [
list_extract(list_sort(list(x)),cast(ceil(count(x)*0.25) AS INTEGER)),
list_extract(list_sort(list(x)),cast(ceil(count(x)*0.75) AS INTEGER))]''')
for name in ['alunos_geral','progresso','progresso_total','usuarios_geral']:
    con.execute(f"CREATE TABLE bronze.{name} AS SELECT * FROM read_csv(?,header=true,all_varchar=true)",[str(base/(name+'.csv'))])
ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
with zipfile.ZipFile(base/'tempo_aula.xlsx') as z:
    shared=[]
    if 'xl/sharedStrings.xml' in z.namelist():
        shared=[''.join(n.itertext()) for n in ET.fromstring(z.read('xl/sharedStrings.xml')).findall('s:si',ns)]
    rows=[]
    for row in ET.fromstring(z.read('xl/worksheets/sheet1.xml')).findall('.//s:row',ns):
        vals=[]
        for c in row.findall('s:c',ns):
            v=c.find('s:v',ns)
            value=v.text if v is not None else ''.join(c.find('s:is',ns).itertext()) if c.find('s:is',ns) is not None else None
            if c.attrib.get('t')=='s': value=shared[int(value)]
            col=re.match('[A-Z]+',c.attrib['r'])[0]
            idx=0
            for ch in col: idx=idx*26+ord(ch)-64
            while len(vals)<idx: vals.append(None)
            vals[idx-1]=value
        rows.append(vals)
headers=rows[0]
# Excel armazena duracoes como fracao de dia.
tempo_idx=headers.index('Tempo')
for row in rows[1:]:
    if len(row)>tempo_idx and row[tempo_idx] is not None and ':' not in row[tempo_idx]:
        seconds=round(float(row[tempo_idx])*86400)
        row[tempo_idx]=f"{seconds//3600:02d}:{seconds%3600//60:02d}:{seconds%60:02d}"
con.execute('CREATE TABLE bronze.tempo_aula ('+','.join('"'+h+'" VARCHAR' for h in headers)+')')
con.executemany('INSERT INTO bronze.tempo_aula VALUES ('+','.join('?' for _ in headers)+')',[r+[None]*(len(headers)-len(r)) for r in rows[1:] if r and r[0] is not None])
con.execute('''CREATE TABLE bronze.asn_aulas_duracao AS SELECT curso_id,modulo_id,aula_id,
curso_titulo AS curso,Tempo AS duracao_hhmmss,
try_cast(split_part(Tempo,':',1) AS DOUBLE)*3600
+try_cast(split_part(Tempo,':',2) AS DOUBLE)*60
+try_cast(split_part(Tempo,':',3) AS DOUBLE) AS duracao_segundos FROM bronze.tempo_aula''')
view_count=0
for q in queries:
    if not isinstance(q,exp.Create): continue
    assert q.kind=='VIEW'
    adapted=q.copy()
    for t in adapted.find_all(exp.Table):
        if t.catalog=='case_asn': t.set('catalog',None)
    out=adapted.sql(dialect='duckdb').replace('APPROX_QUANTILE(','LOCAL_PERCENTILE(')
    try: con.execute(out)
    except Exception:
        print('FALHA EM',q.this.name); raise
    view_count+=1
con.execute('CREATE TEMP TABLE _validation_snapshot AS SELECT * FROM vw_abt_v3_aluno')
for q in homologacao:
    if isinstance(q,exp.Create):
        local_check=q.copy()
        for table in local_check.find_all(exp.Table):
            if table.name=='vw_abt_v3_aluno': table.set('this',exp.to_identifier('_validation_snapshot'))
        con.execute(local_check.sql(dialect='duckdb'))
failures=con.execute('SELECT teste,falhas FROM v3_homologacao WHERE falhas>0').fetchall()
print('DIAGNOSTICOS',failures,flush=True)
assert all(name=='dim_completa_duracao_invalida' and count==1 for name,count in failures),failures

result=con.execute('SELECT COUNT(*),COUNT(DISTINCT aluno_id),COUNT_IF(elegivel_v2) FROM vw_abt_v3_aluno').fetchone()
assert result==(73,73,62),result
assert con.execute('SELECT COUNT(*) FROM vw_abt_v3_aluno WHERE qtd_registros_aula=0').fetchone()[0]==7
assert con.execute('SELECT COUNT(*) FROM vw_abt_v3_aluno WHERE NOT elegivel_v2 AND numero_acessos_v2 IS NOT NULL').fetchone()[0]==0
assert con.execute('SELECT COUNT(*) FROM vw_abt_v3_aluno WHERE elegivel_v2 AND NOT tem_registro_aula AND numero_acessos_v2<>0').fetchone()[0]==0
assert con.execute('SELECT COUNT(*) FROM vw_abt_v3_aluno WHERE taxa_aproveit_acessos_v2 NOT BETWEEN 0 AND 1').fetchone()[0]==0
# Mutacao significativa: duplicar uma matricula nao pode multiplicar a base V2.
before=con.execute('SELECT COUNT(*) FROM v3_v2_progresso_total_filtrado').fetchone()[0]
con.execute("INSERT INTO bronze.alunos_geral SELECT * FROM bronze.alunos_geral WHERE status='Matrícula ativa' LIMIT 1")
after=con.execute('SELECT COUNT(*) FROM v3_v2_progresso_total_filtrado').fetchone()[0]
assert before==after,(before,after)
con.execute('SELECT * FROM vw_abt_v3_aluno').fetchall()
# Duracao zero nao pode abortar por divisao por zero no progresso V2.
con.execute('UPDATE bronze.asn_aulas_duracao SET duracao_segundos=0')
assert con.execute('SELECT COUNT(progresso_pct) FROM v3_v2_abt_engajamento_aluno').fetchone()[0]==0
con.execute('SELECT * FROM vw_abt_v3_aluno').fetchall()
report={'status':'PASS_LOCAL_SMOKE','views':view_count,'alunos':result[0],'alunos_distintos':result[1],'elegiveis_v2':result[2],
'colunas_saida':len(con.execute('DESCRIBE vw_abt_v3_aluno').fetchall()),
'dimensao_teste':'manual parcial usada como fixture; dimensao completa V2 ausente',
'databricks_executado':False,'teste_matricula_duplicada':'PASS','teste_denominador_zero':'PASS','alertas_fixture':failures,
'limites':'transpilacao DuckDB; percentis locais por posto; sem certificacao numerica da V2'}
(folder/'validacao_local.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(report,ensure_ascii=False))
