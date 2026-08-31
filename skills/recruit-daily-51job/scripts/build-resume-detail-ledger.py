#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build-resume-detail-ledger.py —— 从 51job inspect/talent-detail JSON 生成「人才简历详情台账」

规范（2026-08-31 固化，见工作区 AGENTS.md「产物落点」）：
- 输出：02-sourcing/人才简历详情台账.csv（utf-8-sig 带 BOM，Excel 友好）
- 首列日期 yyyy-MM-dd = 获取详情当天日期；同 resumeId 再次获取 → 更新原行（日期改为本轮），不新增重复行
- 列固定：日期,resumeId,姓名,应聘岗位,求职意向,基本画像,技能标签,工作经历,教育背景,简历URL,来源入口,备注
- 多段经历用 || 分条、段内 | 分隔（公司|时段|职责）；文本内 |/; 转义防破列
- 简历URL 只保留 ...detail?resumeId=<ID> 核心段（去 requestId，防下次失效）

用法：
  python build-resume-detail-ledger.py <JSON或目录> [--date 2026-08-31] [--source 20260831推荐] [--job 销售主管]
"""
import json, glob, sys, os, re, csv, argparse
from datetime import date

DEFAULT_OUT = '02-sourcing/人才简历详情台账.csv'
FIELDNAMES = ['日期','resumeId','姓名','应聘岗位','求职意向','基本画像','技能标签','工作经历','教育背景','简历URL','来源入口','备注']

def clean(s, maxlen=None):
    if s is None: return ''
    s = str(s).replace('\n',' ').replace('\r',' ').strip()
    s = re.sub(r'\s+',' ',s)
    s = s.replace('|','／').replace(';','；')
    if maxlen: s = s[:maxlen]
    return s

def short_url(url):
    if not url: return ''
    m = re.match(r'(https?://[^\s?]+?/detail\?.*?resumeId=\d+)', url)
    return m.group(1) if m else url[:150]

def parse_status(st):
    age = re.search(r'(\d+)岁', st)
    exp = re.search(r'(\d+)年经验', st)
    edu = '硕士' if '硕士' in st else ('本科' if '本科' in st else ('大专' if '大专' in st else ''))
    loc = re.search(r'现居·([^\s]+)', st)
    act = re.search(r'(刚刚活跃|当前在线|\d+小时内活跃|\d+日内活跃|\d+周内活跃|\d+个月内活跃)', st)
    return {'age': age.group(1) if age else '', 'exp': exp.group(1) if exp else '',
            'edu': edu, 'loc': loc.group(1) if loc else '', 'active': act.group(1) if act else ''}

def work_to_str(wl):
    parts = []
    for w in wl or []:
        parts.append(f"{clean(w.get('company',''),80)}|{clean(w.get('period',''),40)}|{clean(w.get('desc',''),600)}")
    return ' || '.join(parts)

def edu_to_str(el):
    parts = []
    for e in el or []:
        parts.append(f"{clean(e.get('school',''),50)}|{clean(e.get('degree',''),20)}|{clean(e.get('major',''),40)}|{clean(e.get('period',''),30)}")
    return ' || '.join(parts)

def load_data(input_path):
    seen, order = {}, []
    files = sorted(glob.glob(os.path.join(input_path, '*.json'))) if os.path.isdir(input_path) else [input_path]
    for f in files:
        try:
            obj = json.load(open(f, encoding='utf-8'))
            if isinstance(obj, dict) and obj.get('resumeId'):
                rid = str(obj['resumeId'])
                seen[rid] = obj
                if rid not in order: order.append(rid)
        except Exception:
            continue
    return seen, order

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('input', help='JSON 目录或单个 JSON 文件')
    ap.add_argument('--date', default=date.today().isoformat(), help='获取日期 yyyy-mm-dd（默认今天）')
    ap.add_argument('--source', default='', help='来源入口，如 20260831推荐')
    ap.add_argument('--job', default='', help='应聘岗位，如 销售主管')
    ap.add_argument('--out', default=DEFAULT_OUT)
    args = ap.parse_args()

    data, order = load_data(args.input)

    # 读已有台账（若存在）用于 upsert
    existing_rows = []
    if os.path.exists(args.out):
        with open(args.out, encoding='utf-8-sig', newline='') as f:
            existing_rows = list(csv.DictReader(f))

    new_rows = []
    for rid in order:
        d = data[rid]
        info = parse_status(d.get('status',''))
        profile = ' / '.join([x for x in [f"{info['age']}岁", f"{info['exp']}年", info['edu'], info['loc'], info['active']] if x])
        job = d.get('forJob') or args.job or ''
        new_rows.append({
            '日期': args.date,
            'resumeId': rid,
            '姓名': clean(d.get('name',''),20),
            '应聘岗位': clean(job,20),
            '求职意向': clean(d.get('intention',''),200),
            '基本画像': profile,
            '技能标签': '、'.join(clean(x,20) for x in d.get('skills',[]) or []),
            '工作经历': work_to_str(d.get('work',[])),
            '教育背景': edu_to_str(d.get('edu',[])),
            '简历URL': short_url(d.get('url','')),
            '来源入口': args.source or '',
            '备注': '',
        })

    # merge: 既有行保留；本批同 rid 更新
    merged = {}
    for r in existing_rows:
        merged[r.get('resumeId','')] = r
    for r in new_rows:
        merged[r['resumeId']] = r
    # 保序：先既有（原地），后新加的
    final = []
    seen_final = set()
    for r in existing_rows:
        rid = r.get('resumeId','')
        if rid and rid not in seen_final:
            final.append(merged[rid]); seen_final.add(rid)
    for rid in order:
        if rid not in seen_final:
            final.append(merged[rid]); seen_final.add(rid)

    with open(args.out, 'w', encoding='utf-8-sig', newline='') as f:
        w = csv.DictWriter(f, fieldnames=FIELDNAMES)
        w.writeheader()
        w.writerows(final)
    print(f'已写 {args.out} | 总行 {len(final)}（本批 {len(new_rows)}）')

if __name__ == '__main__':
    main()