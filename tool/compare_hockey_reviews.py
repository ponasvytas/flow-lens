"""Compare independent, clip-aligned hockey coding worksheets (stdlib only)."""

import argparse
import csv
import json
import math
from collections import Counter
from pathlib import Path
from statistics import median


ROOT = Path(__file__).resolve().parents[1]


def read_reviews(path, taxonomy):
    types = {
        event['eventTypeId']: (category['categoryId'], event)
        for category in taxonomy['categories']
        for event in category['eventTypes']
    }
    fields = {field['id']: field for field in taxonomy['contextFields']}
    rows = {}
    with Path(path).open(encoding='utf-8-sig', newline='') as source:
        reader = csv.DictReader(source)
        required = {'clip_id', 'category_id', 'event_type_id', 'grade',
                    'context_json', 'tagging_seconds'}
        if not required.issubset(reader.fieldnames or []):
            raise ValueError(f'{path}: missing columns {sorted(required - set(reader.fieldnames or []))}')
        for line, row in enumerate(reader, 2):
            clip = row['clip_id'].strip()
            if not clip:
                raise ValueError(f'{path}:{line}: missing clip_id')
            if clip in rows:
                raise ValueError(f'{path}:{line}: duplicate clip_id {clip}')
            event_id = row['event_type_id'].strip()
            entry = types.get(event_id)
            if not entry or entry[0] != row['category_id'].strip() or entry[1].get('archived', False):
                raise ValueError(f'{path}:{line}: invalid or archived category/type pair')
            grade = row['grade'].strip().lower() or 'ungraded'
            if grade not in {'positive', 'neutral', 'negative', 'ungraded'}:
                raise ValueError(f'{path}:{line}: invalid grade')
            context = json.loads(row['context_json'] or '{}')
            if not isinstance(context, dict):
                raise ValueError(f'{path}:{line}: context_json must be an object')
            for key, value in context.items():
                field = fields.get(key)
                if not field or not isinstance(value, str) or (field['options'] and value not in field['options']):
                    raise ValueError(f'{path}:{line}: invalid context {key}')
            seconds = float(row['tagging_seconds']) if row['tagging_seconds'].strip() else None
            if seconds is not None and (seconds < 0 or not math.isfinite(seconds)):
                raise ValueError(f'{path}:{line}: tagging_seconds must be finite and nonnegative')
            rows[clip] = {'category_id': entry[0], 'event_type_id': event_id,
                          'grade': grade, 'context': context, 'seconds': seconds}
    return rows


def compare(left, right):
    shared = sorted(left.keys() & right.keys())
    agreement = {}
    confusions = {}
    for field in ('category_id', 'event_type_id', 'grade'):
        matches = sum(left[clip][field] == right[clip][field] for clip in shared)
        agreement[field] = {'matches': matches, 'compared': len(shared),
                            'fraction': matches / len(shared) if shared else None}
        counts = Counter((left[clip][field], right[clip][field]) for clip in shared
                         if left[clip][field] != right[clip][field])
        confusions[field] = [{'reviewer_a': a, 'reviewer_b': b, 'count': count}
                            for (a, b), count in sorted(counts.items())]
    context_disagreements = []
    for clip in shared:
        a, b = left[clip]['context'], right[clip]['context']
        for field in sorted(a.keys() | b.keys()):
            if a.get(field) != b.get(field):
                context_disagreements.append({'clip_id': clip, 'field': field,
                                              'reviewer_a': a.get(field), 'reviewer_b': b.get(field)})
    timing = {}
    for label, rows in [('reviewer_a', left), ('reviewer_b', right)]:
        times = [rows[clip]['seconds'] for clip in shared if rows[clip]['seconds'] is not None]
        timing[label] = {'timed_shared_clips': len(times), 'median_seconds': median(times) if times else None}
    return {'shared_clips': len(shared), 'only_reviewer_a': sorted(left.keys() - right.keys()),
            'only_reviewer_b': sorted(right.keys() - left.keys()), 'agreement': agreement,
            'confusions': confusions, 'context_disagreements': context_disagreements,
            'timing': timing}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('reviewer_a', type=Path)
    parser.add_argument('reviewer_b', type=Path)
    parser.add_argument('--taxonomy', type=Path, default=ROOT / 'assets/sports/hockey.json')
    args = parser.parse_args()
    try:
        taxonomy = json.loads(args.taxonomy.read_text(encoding='utf-8'))
        result = compare(read_reviews(args.reviewer_a, taxonomy), read_reviews(args.reviewer_b, taxonomy))
    except (OSError, ValueError, TypeError) as error:
        parser.error(str(error))
    result['taxonomy_revision'] = taxonomy['revision']
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
