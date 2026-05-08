#!/usr/bin/env bash
# Static release gates: manifest version sync + confidence gate hardening.
set -euo pipefail

PLUGIN_DIR="${PLUGIN_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

python3 - "$PLUGIN_DIR" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
manifest_files = [
    'plugin.json',
    '.claude-plugin/plugin.json',
    '.claude-plugin/marketplace.json',
    '.codebuddy-plugin/plugin.json',
    '.codebuddy-plugin/marketplace.json',
]
versions = []
errors = []
for rel in manifest_files:
    path = root / rel
    data = json.loads(path.read_text(encoding='utf-8'))
    if 'version' in data:
        versions.append((rel, data['version']))
    for idx, plugin in enumerate(data.get('plugins', []) or []):
        if plugin.get('name') == 'pua':
            versions.append((f'{rel}:plugins[{idx}]', plugin.get('version')))

unique = {v for _, v in versions}
if len(unique) != 1:
    errors.append('version mismatch: ' + repr(versions))
version = next(iter(unique)) if unique else None
if not version:
    errors.append('no version detected')

claude_market = json.loads((root / '.claude-plugin/marketplace.json').read_text(encoding='utf-8'))
plugin_desc = claude_market['plugins'][0].get('description', '')
if version and f'v{version}:' not in plugin_desc:
    errors.append(f'.claude-plugin/marketplace.json plugin description missing changelog marker v{version}:')

skill = (root / 'skills/pua/SKILL.md').read_text(encoding='utf-8')
required_terms = [
    '信心门控（Confidence Gate）',
    '列声明',
    '找漏洞',
    'P0/P1',
    '跑证据',
    '循环判定',
    '事实上的 100%',
    '缓存/发布链路',
    'hook smoke test',
]
for term in required_terms:
    if term not in skill:
        errors.append(f'confidence gate missing required term: {term}')

for forbidden in ['Applies to ALL task types', 'All task types', 'code, config, debug, deploy, research']:
    if forbidden in skill.split('---', 2)[1]:
        errors.append(f'pua skill description is too broad and may false-trigger: {forbidden}')
if 'Do not trigger for normal first-attempt coding or information requests.' not in skill.split('---', 2)[1]:
    errors.append('pua skill description must explicitly exclude normal first-attempt requests')

command = (root / 'commands/pua.md').read_text(encoding='utf-8')
command_frontmatter = command.split('---', 2)[1]
if 'Use only when the user explicitly invokes /pua' not in command_frontmatter:
    errors.append('pua slash command description must be explicit-invocation only')
if '任务描述]' in command_frontmatter or '任意任务描述' in command_frontmatter:
    errors.append('pua slash command frontmatter is too broad and may false-trigger')

hook = (root / 'hooks/pua-loop-hook.sh').read_text(encoding='utf-8')
if 'run_with_timeout 120 bash -c "$VERIFY_CMD"' not in hook:
    errors.append('pua-loop hook does not use portable run_with_timeout for verify_command')
if 'VERIFY_OUTPUT=$(timeout 120 bash -c "$VERIFY_CMD"' in hook:
    errors.append('pua-loop hook still calls GNU timeout directly')

helpers = (root / 'evals/test-helpers.sh').read_text(encoding='utf-8')
trigger = (root / 'evals/run-trigger-test.sh').read_text(encoding='utf-8')
if 'run_with_timeout()' not in helpers:
    errors.append('eval helper missing portable run_with_timeout')
if '    timeout 120 claude' in trigger or '    timeout 90 claude' in helpers:
    errors.append('eval scripts still call GNU timeout directly')
if '--output-format stream-json' in trigger and '--verbose' not in trigger:
    errors.append('trigger eval uses stream-json without --verbose')
if 'PUA_CONFIG="$EVAL_PUA_CONFIG" run_with_timeout 120 claude' not in trigger:
    errors.append('trigger eval must use isolated PUA_CONFIG to avoid user ~/.pua/config.json')
if 'EVAL_WORKSPACE="$RESULTS_DIR/workspace"' not in trigger or 'cd "$EVAL_WORKSPACE"' not in trigger:
    errors.append('trigger eval must run in a neutral workspace, not the pua plugin repo')
if 'PUA_CONFIG="$eval_config" run_with_timeout 90 claude' not in helpers:
    errors.append('behavior eval must use isolated PUA_CONFIG to avoid user ~/.pua/config.json')

if errors:
    print('=== Release consistency FAILED ===')
    for e in errors:
        print(' -', e)
    sys.exit(1)

print('=== Release consistency OK ===')
print('version =', version)
print('manifests checked =', len(manifest_files))
print('confidence gate terms checked =', len(required_terms))
PY
