#!/usr/bin/env python3
import json, sys
from pathlib import Path
if len(sys.argv) != 2:
    print('Usage: validate_dossier.py <dossier-dir>', file=sys.stderr); sys.exit(2)
dir = Path(sys.argv[1])
required = ['intake.md','connector-report.json','source-index.json','evidence-graph.json','evidence-dossier.md','recommended-brief.md','open-questions.md']
missing = [f for f in required if not (dir/f).exists()]
if missing:
    print('Missing required files: '+', '.join(missing), file=sys.stderr); sys.exit(1)
def read_json(name):
    try: return json.loads((dir/name).read_text())
    except Exception as e:
        print(f'Invalid JSON in {name}: {e}', file=sys.stderr); sys.exit(1)
source = read_json('source-index.json')
graph = read_json('evidence-graph.json')
if not source.get('dossier_id') or not isinstance(source.get('items'), list):
    print('source-index.json missing dossier_id/items', file=sys.stderr); sys.exit(1)
if graph.get('dossier_id') != source.get('dossier_id'):
    print('evidence-graph dossier_id mismatch', file=sys.stderr); sys.exit(1)
if not isinstance(graph.get('items'), list):
    print('evidence-graph items missing', file=sys.stderr); sys.exit(1)
dossier = (dir/'evidence-dossier.md').read_text()
for section in ['High-Purity Facts','Stale or Low-Purity Evidence','Contradictions','Demo Opportunities','Critical Unknowns']:
    if section not in dossier:
        print(f'evidence-dossier.md missing {section}', file=sys.stderr); sys.exit(1)
brief = (dir/'recommended-brief.md').read_text()
for section in ['Proposal Objective','Demo Wow Moment','Evidence Map']:
    if section not in brief:
        print(f'recommended-brief.md missing {section}', file=sys.stderr); sys.exit(1)
print(json.dumps({'status':'pass','dossier_id':source['dossier_id'],'sources':len(source['items']),'scored':len(graph['items'])}, indent=2))
