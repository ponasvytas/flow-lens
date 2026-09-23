import csv
import json
import tempfile
import unittest
from pathlib import Path

from compare_hockey_reviews import ROOT, compare, read_reviews


class ReviewComparisonTest(unittest.TestCase):
    def test_agreement_excludes_missing_clips_and_reports_confusions(self):
        row = {'category_id': 'shot', 'event_type_id': 'shot_saved',
               'grade': 'ungraded', 'context': {}, 'seconds': 3}
        other = dict(row, event_type_id='shot_goal', grade='positive',
                     context={'side': 'Our team'}, seconds=5)
        result = compare({'1': row, '2': row, 'missing': row}, {'1': row, '2': other})
        self.assertEqual(result['shared_clips'], 2)
        self.assertEqual(result['agreement']['event_type_id']['fraction'], 0.5)
        self.assertEqual(result['agreement']['category_id']['fraction'], 1)
        self.assertEqual(result['only_reviewer_a'], ['missing'])
        self.assertEqual(result['timing']['reviewer_b']['median_seconds'], 4)
        self.assertEqual(result['context_disagreements'][0]['field'], 'side')
        self.assertEqual(result['confusions']['grade'][0]['count'], 1)

    def test_no_overlap_is_not_perfect_agreement(self):
        self.assertIsNone(compare({}, {})['agreement']['grade']['fraction'])

    def test_parser_rejects_archived_pairs_duplicate_clips_and_bad_values(self):
        taxonomy = json.loads((ROOT / 'assets/sports/hockey.json').read_text())
        row = ['clip-1', 'shot', 'shot_saved', '', '{}', '4.5']
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'review.csv'

            def write(rows):
                with path.open('w', newline='') as target:
                    writer = csv.writer(target)
                    writer.writerow(['clip_id', 'category_id', 'event_type_id', 'grade', 'context_json', 'tagging_seconds'])
                    writer.writerows(rows)

            write([row])
            self.assertEqual(read_reviews(path, taxonomy)['clip-1']['grade'], 'ungraded')
            for rows in [[row, row], [row[:2] + ['shot_on_net'] + row[3:]],
                         [row[:1] + ['pass'] + row[2:]], [row[:5] + ['nan']],
                         [row[:4] + ['{"unknown":"value"}'] + row[5:]]]:
                write(rows)
                with self.assertRaises(ValueError):
                    read_reviews(path, taxonomy)


if __name__ == '__main__':
    unittest.main()
