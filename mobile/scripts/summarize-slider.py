"""Summarize an anonymous CAPTCHA run without dropping failed challenges."""
import collections
import json
import sys
from pathlib import Path

source = Path(sys.argv[1])
run = json.loads(source.read_text(encoding='utf-8-sig'))
assert run['state'] == 'complete', 'Only a completed fixed sample may be reported'
assert run['submittedAccountCredentials'] is False
rounds = run['rounds']
attempts = [a for r in rounds for a in r['attempts']]
assert all(len(r['attempts']) <= 3 for r in rounds)
assert all(r['verified'] == any(a.get('serverCode') == 1 for a in r['attempts']) for r in rounds)
passed = sum(a.get('serverCode') == 1 for a in attempts)
completed = sum(r['verified'] for r in rounds)
assert (len(rounds), len(attempts), passed, completed) == (
    run['roundCount'], run['challengeCount'], run['successfulChallenges'], run['successfulRounds'])

def ratio(success, total):
    return {'success': success, 'total': total, 'percent': 100 * success / total if total else None}

summary = {
    'source': source.name,
    'label': run['label'],
    'environment': run['environment'],
    'submittedAccountCredentials': False,
    'singleChallenge': ratio(passed, len(attempts)),
    'withinThree': ratio(completed, len(rounds)),
    'firstChallenge': ratio(sum(bool(r['attempts']) and r['attempts'][0].get('serverCode') == 1 for r in rounds), len(rounds)),
    'failureBreakdown': dict(collections.Counter(
        ('serverCode:' + str(a['serverCode'])) if a.get('serverCode') is not None
        else a.get('error', 'no_verification_response')
        for a in attempts if a.get('serverCode') != 1)),
    'roundErrors': dict(collections.Counter(r.get('error', 'unknown') for r in rounds if not r['verified'])),
}
output = json.dumps(summary, ensure_ascii=False, indent=2) + '\n'
if len(sys.argv) > 2:
    Path(sys.argv[2]).write_text(output, encoding='utf-8')
print(output)
