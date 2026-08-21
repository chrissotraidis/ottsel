# F1 user-pack preparation helper — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | F1 — legal user-data import and save persistence |
| Change | Added `scripts/prepare-user-data-pack.sh`. It accepts an already extracted user-owned Jak 1 tree plus optional derived `fr3` directory, refuses repository output, copies only the nine required families, writes `OTTSEL_USER_DATA_V1` metadata and relative SHA-256 coverage, and leaves the result outside the repository for Files delivery. |
| Focused proof | A temporary non-game fixture with all nine families produced an 11-file pack; `scripts/validate-user-data-pack.sh` accepted it; `bash -n` and `git diff --check` passed. |
| Safety | No protected data was copied into the repository, bundled, or committed. The helper does not install, sign, or embed the pack. |
| Verdict | PASS — preparation/validation tooling is reproducible. Legal user-data delivery through Files and the subsequent live route remain open. |
| Next gate | Run the helper against a legal extracted tree, deliver the resulting pack through Files, then verify durable import and the real Metal route. |

