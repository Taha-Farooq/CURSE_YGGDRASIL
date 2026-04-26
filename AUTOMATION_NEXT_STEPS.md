# CURSE Automation - Step-by-Step Next Actions

Follow this checklist in order. Do not skip steps.

## 1) Confirm files are present

You should now have:
- `REQUIREMENTS.md`
- `FEEDBACK_SCHEMA.json`
- `INTERACTION_MATRIX_TEMPLATE.md`
- `INTERACTION_MATRIX.md`
- `ONE_PERSON_TEAM_LOOP.md`
- `scripts/quality-gate.ps1`
- `scripts/dev-loop.ps1`
- `.github/workflows/quality-gate.yml`

## 2) Run local quality gate

From repo root in PowerShell:

```powershell
./scripts/quality-gate.ps1
```

Expected result: `[quality-gate] PASS`

If it fails, fix the reported file/section first.

## 3) Run the automated daily loop

```powershell
./scripts/dev-loop.ps1
```

This will:
- run the quality gate
- create a timestamped summary report in `reports/`

## 4) Wire your real project tests into strict mode

Edit `scripts/quality-gate.ps1` and replace placeholders under strict mode with your actual commands.
Examples:
- `npm test`
- `dotnet test`
- `python -m pytest`
- custom game simulation test command

Then run:

```powershell
./scripts/quality-gate.ps1 -Strict
```

## 5) Start using the interaction matrix as a merge requirement

For every feature change:
1. Update `INTERACTION_MATRIX.md` rows touched by the change.
2. Add/adjust `integration_test_ids`.
3. Add the corresponding tests in your test harness.
4. Run `quality-gate` before merging.

## 6) Enable CI

Push this repo to GitHub and ensure Actions are enabled.
The workflow at `.github/workflows/quality-gate.yml` will run automatically on push/PR.

## 7) Add feedback ingestion (first API)

Create a minimal endpoint in your backend:
- `POST /feedback`
- validates request body against `FEEDBACK_SCHEMA.json`
- stores valid items in DB (status = `new`)
- rejects invalid schema payloads

## 8) Add first bot in this order

Implement bots one-by-one:
1. `validation_bot` (blocks bad releases)
2. `world_explorer_bot` (finds broken routes/softlocks)
3. `route_clearability_bot` (flags unclear/unfun progression)
4. `assisted_feature_bot` (guarded, review-required)

## 9) Define release gates before content scale

Require all before promotion to staging/prod:
- quality gate pass
- validator bot pass
- critical path tests pass
- replay event coverage pass
- no unresolved critical feedback regressions

## 10) Operate weekly review cadence

Every week:
- review top feedback clusters:
  - not fun
  - not working
  - not fitting theme
- choose top 3 changes
- run dev-loop + targeted human playtest
- publish short changelog linked to feedback IDs

## Immediate 48-hour target

Day 1:
- run local scripts successfully
- wire strict-mode tests
- activate GitHub Actions quality gate

Day 2:
- ship minimal `/feedback` endpoint with schema validation
- implement first version of `validation_bot` logic and hook into CI

