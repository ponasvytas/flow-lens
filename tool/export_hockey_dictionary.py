"""Regenerate the coach-facing dictionary from the shipped taxonomy asset."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
taxonomy = json.loads((root / 'assets/sports/hockey.json').read_text(encoding='utf-8'))
lines = ['# Hockey coding dictionary', '', f"Revision: `{taxonomy['revision']}`. Generated from `assets/sports/hockey.json`.", '',
         'Use the [validation protocol](README.md) for perspective, timestamps, counting and grading rules.', '',
         'Each active row is a selectable observation. Context descriptors refine it; grades assess execution separately.', '']


def cell(value):
    return str(value).replace('|', '\\|').replace('\n', ' ')


for category in taxonomy['categories']:
    lines += [f"## {category['name']} (`{category['categoryId']}`)", '', category.get('description', ''), '',
              '| Choice / stable ID | Coding definition |', '| --- | --- |']
    for event in category['eventTypes']:
        if not event.get('archived'):
            lines.append(f"| {cell(event['name'])} / `{event['eventTypeId']}` | {cell(event['definition'])} |")
    lines += ['', 'Context: ' + ', '.join(field['name'] for field in taxonomy['contextFields']
                                       if field['id'] in category.get('contextFieldIds', [])) + '.', '']
lines += ['## Historical choices', '',
          'These remain resolvable in saved events and existing quick menus. They are excluded from new-choice pickers. '
          'No deterministic conversion can resolve their historical ambiguity; rewatch footage before recoding.', '',
          '| Original pair | Saved meaning / limitation |', '| --- | --- |']
for category in taxonomy['categories']:
    for event in category['eventTypes']:
        if event.get('archived'):
            lines.append(f"| `{category['categoryId']}/{event['eventTypeId']}` | {cell(event['definition'])} |")
lines += ['', '## Optional context fields', '', '| Field / ID | Values | Guidance |', '| --- | --- | --- |']
for field in taxonomy['contextFields']:
    lines.append(f"| {cell(field['name'])} / `{field['id']}` | {cell(', '.join(field['options']) or 'Free text')} | {cell(field.get('description', ''))} |")
lines += ['', '## Manual tracking dictionary', '',
          'Track counts are an independent source. Aggregate counters retain their original scope; '
          'do not add an aggregate to its component counters or to Record totals.', '',
          '| Tracker / stable ID | Definition |', '| --- | --- |']
for tracker in taxonomy['trackingPresets']:
    lines.append(f"| {cell(tracker['label'])} / `{tracker['id']}` | {cell(tracker.get('definition', ''))} |")
(root / 'specs/hockey-taxonomy-validation/coding-dictionary.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
