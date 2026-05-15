#!/usr/bin/env python3
import json, os, shutil, subprocess
from pathlib import Path

def has(cmd, args=("--version",)):
    if not shutil.which(cmd): return False
    try:
        r = subprocess.run([cmd, *args], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return r.returncode in (0, 1)
    except Exception:
        return False

def run(cmd, args):
    try:
        r = subprocess.run([cmd, *args], capture_output=True, text=True)
        return r.returncode
    except Exception:
        return 127

cfg = Path.home()/'.codex/config.toml'
checks = {
    'node': has('node'),
    'python3': has('python3'),
    'slackMcpConfig': cfg.exists() and '[mcp_servers.slack]' in cfg.read_text(errors='ignore'),
    'gws': has('gws', ('--help',)),
    'gh': has('gh'),
    'ghAuthOk': run('gh', ['auth', 'status']) == 0 if has('gh') else False,
    'localFiles': True
}
sources=[]
if checks['slackMcpConfig']: sources.append({'source':'slack','status':'available','note':'MCP config detected; use MCP Slack tools in-agent'})
if checks['gws']: sources.append({'source':'google_workspace','status':'available','note':'gws CLI detected; auth checked per command'})
if checks['gh']: sources.append({'source':'github','status':'available' if checks['ghAuthOk'] else 'auth_invalid','note':'gh auth ok' if checks['ghAuthOk'] else 'run gh auth login -h github.com'})
sources.append({'source':'local_files','status':'available','note':'read user-provided files/images in allowed workspace'})
print(json.dumps({'checks':checks,'sources':sources,'blockers':[s for s in sources if s['status']=='auth_invalid']}, indent=2))
