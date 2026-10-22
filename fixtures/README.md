# Shared scoring fixtures

These files are the contract between DClutter for Windows (this repo) and
DClutter for macOS ([RokiTheWise/DClutter](https://github.com/RokiTheWise/DClutter)).
Both apps run every case, so the same Downloads folder is ranked the same
way on either platform.

**Change them in both repos at once.** If a weight or matching rule changes,
update the case here, copy the file to the other repo, and make both test
suites pass before merging either side.

## `queue.json`

Each case lists candidates and what to expect for them.

Candidate fields:

| Field | Meaning | Default |
|---|---|---|
| `id` | Name used in `expect` and `expectRank` | required |
| `name` | File or folder name; the parent folder doesn't matter | required |
| `bytes` | Size in bytes | required |
| `isDirectory` | Whether it's a folder | `false` |
| `createdDaysAgo` | Created this many days before `now` | `0` |
| `modifiedDaysAgo` | Modified this many days before `now` | absent |
| `lastOpenedDaysAgo` | Last opened this many days before `now` | absent |
| `sourceURL` | Where it was downloaded from | absent |

Turn a `…DaysAgo` value into a timestamp as `now - days * 86400` seconds.
Negative values mean the date is in the future.

Each `expect` entry checks only the fields it lists: `score` (within
`tolerance`), `redundantCopy`, `extractedArchive` and `duplicateCount`.
`expectRank`, when present, is the full order `rank` must return. A case's
optional `weights` overrides individual default weights.

## `generic-names.json`

File names that must, or must not, count as auto-generated for the
ambiguous-name penalty.
