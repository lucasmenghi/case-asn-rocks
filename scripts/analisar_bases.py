"""Perfil agregado dos arquivos locais, sem modificar bases ou publicar dados individuais.

Uso: python scripts/analisar_bases.py --pasta "pasta com os CSV e tempo_aula.xlsx"
Dependências de leitura: pandas e openpyxl.
"""
from pathlib import Path
import argparse
import json
import re
from collections import Counter
import pandas as pd


def duracao(v):
    m = re.fullmatch(r'(\d+):(\d{2}):(\d{2})', str(v))
    if not m:
        return float('nan')
    h, mi, s = map(int, m.groups())
    return h * 3600 + mi * 60 + s if mi < 60 and s < 60 else float('nan')


def resumo(s):
    s = pd.to_numeric(s, errors='coerce')
    return {'validos': int(s.count()), 'nulos': int(s.isna().sum()),
            **{k: float(v) for k, v in s.describe(percentiles=[.25,.5,.75]).items() if k != 'count'},
            'zeros': int(s.eq(0).sum()), 'negativos': int(s.lt(0).sum())}


def analisar(pasta):
    nomes = ['usuarios_geral', 'alunos_geral', 'progresso', 'progresso_total']
    ds = {n: pd.read_csv(pasta / (n + '.csv'), dtype=str, keep_default_na=True) for n in nomes}
    ds['tempo_aula'] = pd.read_excel(pasta / 'tempo_aula.xlsx', dtype=str)
    out = {'fontes': 'CSV locais e tempo_aula.xlsx; não consulta a bronze do Databricks', 'tabelas': {}}
    for nome, df in ds.items():
        tab = {'linhas': len(df), 'colunas': len(df.columns), 'linhas_duplicadas': int(df.duplicated().sum()),
               'campos': {}}
        for c in df:
            s = df[c]
            campo = {'nulos': int(s.isna().sum()), 'distintos': int(s.nunique())}
            if s.nunique() <= 12 and not c.endswith('_id'):
                campo['valores'] = {str(k): int(v) for k,v in s.value_counts().items()}
            if ('data' in c or c in ['inicio', 'cadastro', 'expira', 'suporte', 'ultima_visualizacao', 'ultimo_acesso']) and c != 'log_id':
                t = pd.to_datetime(s, errors='coerce', utc=True, format='mixed')
                campo['datas'] = {'min': str(t.min()), 'max': str(t.max()),
                                  'invalidas_preenchidas': int((s.notna() & t.isna()).sum())}
            tab['campos'][c] = campo
        if 'aluno_id' in df:
            tab['alunos'] = int(df.aluno_id.nunique())
        if 'curso_id' in df:
            tab['cursos'] = int(df.curso_id.nunique())
        out['tabelas'][nome] = tab
    u,a,pr,pt=(ds[n] for n in nomes)
    extra={}
    extra['matriculas_por_aluno'] = resumo(a.groupby('aluno_id').size())
    extra['distribuicao_matriculas_por_aluno'] = {str(k):int(v) for k,v in a.groupby('aluno_id').size().value_counts().sort_index().items()}
    extra['matriculas_por_safra'] = a.cadastro_data.value_counts().to_dict()
    extra['alunos_por_safra_matricula'] = a.groupby('cadastro_data').aluno_id.nunique().to_dict()
    extra['progresso_pct'] = resumo(pr.progresso)
    extra['progresso_pct_positivo'] = resumo(pd.to_numeric(pr.progresso)[lambda x:x>0])
    extra['progresso_100'] = int(pd.to_numeric(pr.progresso).eq(100).sum())
    extra['progresso_100_por_curso'] = pr.loc[pd.to_numeric(pr.progresso).eq(100),'curso_titulo'].value_counts().to_dict()
    extra['alunos_progresso_positivo'] = int(pr.loc[pd.to_numeric(pr.progresso).gt(0),'aluno_id'].nunique())
    extra['aulas_acessadas'] = resumo(pr.aulas_acessadas)
    extra['carga_horaria_seg'] = resumo(pr.carga_horaria.map(duracao))
    extra['progresso_positivo_com_carga_zero'] = int((pd.to_numeric(pr.progresso).gt(0) & pr.carga_horaria.map(duracao).eq(0)).sum())
    tempo=pt.tempo_aula.map(duracao)
    extra['tempo_aula_assistido_seg'] = resumo(tempo)
    extra['tempo_aula_total_horas'] = float(tempo.sum()/3600)
    extra['alunos_com_tempo_positivo'] = int(pt.loc[tempo.gt(0),'aluno_id'].nunique())
    extra['tempo_por_aluno_com_log_horas'] = resumo(pt.assign(seg=tempo).groupby('aluno_id').seg.sum(min_count=1)/3600)
    extra['aulas_distintas_por_aluno_com_log'] = resumo(pt.groupby('aluno_id').aula_id.nunique())
    extra['registros_concluido_tempo_zero'] = int((pt.aula_concluido.eq('1') & tempo.eq(0)).sum())
    extra['registros_concluido_tempo_nulo'] = int((pt.aula_concluido.eq('1') & tempo.isna()).sum())
    extra['duplicados_aluno_aula'] = int(pt.duplicated(['aluno_id','aula_id']).sum())
    extra['duplicados_aluno_curso'] = int(a.duplicated(['aluno_id','curso_id']).sum())
    extra['log_igual_modulo'] = int(pt.log_id.eq(pt.modulo_id).sum())
    extra['alunos_sem_log'] = len(set(u.aluno_id)-set(pt.aluno_id))
    extra['logs_aluno_ausente_usuarios'] = int((~pt.aluno_id.isin(u.aluno_id)).sum())
    extra['matriculas_sem_progresso'] = len(set(a.matricula_id)-set(pr.matricula_id))
    extra['progresso_sem_matricula'] = len(set(pr.matricula_id)-set(a.matricula_id))
    joins=pr.merge(a,on='matricula_id',suffixes=('_p','_a'))
    extra['divergencias_chaves_progresso_matricula'] = int((joins.aluno_id_p.ne(joins.aluno_id_a)|joins.curso_id_p.ne(joins.curso_id_a)).sum())
    pairs=set(zip(a.aluno_id,a.curso_id))
    extra['logs_sem_par_matricula'] = sum((x,y) not in pairs for x,y in zip(pt.aluno_id,pt.curso_id))
    extra['top_cursos_por_alunos_com_log'] = pt.groupby('curso_titulo').agg(alunos=('aluno_id','nunique'),registros=('aluno_id','size')).sort_values('alunos',ascending=False).head(8).reset_index().to_dict('records')
    d=ds['tempo_aula']; tc=d.Tempo.map(duracao)
    extra['duracao_oficial_seg'] = resumo(tc)
    extra['duracao_oficial_total_horas'] = float(tc.sum()/3600)
    extra['duracao_oficial_duplicados_chave'] = int(d.duplicated(['curso_id','modulo_id','aula_id']).sum())
    extra['alunos_com_multiplas_datas_matricula'] = int(a.groupby('aluno_id').cadastro_data.nunique().gt(1).sum())
    keys=['curso_id','modulo_id','aula_id']
    cov=pt.assign(seg=tempo).merge(d.assign(oficial=tc)[keys+['oficial']],on=keys,how='left',indicator=True)
    extra['logs_sem_duracao_manual'] = int(cov._merge.eq('left_only').sum())
    extra['logs_com_tempo_acima_duracao'] = int(cov.seg.gt(cov.oficial).sum())
    # Mesmos alunos, matrículas e durações são comparados sem juntar fatos entre si.
    dates=pd.to_datetime(pt.ultima_visualizacao,format='mixed',utc=True,errors='coerce')
    dates2=pd.to_datetime(pt.data_conclusao,format='mixed',utc=True,errors='coerce')
    extra['ultima_visualizacao_posterior_conclusao'] = int(dates.gt(dates2).sum())
    extra['ultima_visualizacao_igual_conclusao'] = int(dates.eq(dates2).sum())
    extra['ultima_visualizacao_anterior_conclusao'] = int(dates.lt(dates2).sum())
    out['analise'] = extra
    return out


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--pasta',type=Path,required=True)
    parser.add_argument('--saida',type=Path)
    args=parser.parse_args()
    result=json.dumps(analisar(args.pasta),ensure_ascii=False,indent=2,allow_nan=False)
    if args.saida:
        args.saida.write_text(result+'\n',encoding='utf-8')
    else:
        print(result)
