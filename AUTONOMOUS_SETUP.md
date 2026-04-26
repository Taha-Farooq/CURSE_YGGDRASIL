# Autonomous Setup (Very Simple)

This project can now run its own validation/test loop.

## What exists now

- `scripts/run-autonomous.ps1` -> one command for autonomous cycle.
- `scripts/install-autonomous-task.ps1` -> installs Windows scheduler job.
- `scripts/uninstall-autonomous-task.ps1` -> removes scheduler job.
- `bots/orchestrator.ps1` -> runs all bots.
- `bots/validation-bot.ps1` -> enforces quality gate + required files.
- `bots/world-explorer-bot.ps1` -> verifies required scenario coverage.
- `bots/route-clearability-bot.ps1` -> clearability score gate.
- `bots/engine-test-bot.ps1` -> runs engine tests (or placeholder pass before engine exists).
- `bots/architecture-extendability-bot.ps1` -> checks readability/extendability signals for future dimensional operations.
- `bots/error-checker-bot.ps1` -> scans generated reports and required files for critical issues.
- `bots/bug-fixer-bot.ps1` -> produces fix suggestions (safe suggestion mode by default).
- `bots/feature-suggester-bot.ps1` -> proposes good-to-have engine features.
- `bots/task-planner-bot.ps1` -> converts requirements into actionable backlog tasks.
- `bots/system-builder-bot.ps1` -> scaffolds core subsystem spec files automatically.
- `bots/implementation-bot.ps1` -> creates implementation plans from backlog tasks.
- `bots/team-growth-bot.ps1` -> expands virtual team roles as task load increases.
- `bots/test-research-bot.ps1` -> researches required test coverage from requirements/matrix.
- `bots/bot-maker-bot.ps1` -> reads handoff requests and scaffolds missing test bot stubs.
- `bots/goal-alignment-bot.ps1` -> checks that work stays aligned to active design goals.
- generated bots in `bots/generated/` are now auto-executed by orchestrator each cycle.
- `automation/automation-config.json` -> controls intervals and bot settings.
- `.github/workflows/autonomous-sweep.yml` -> hourly cloud automation on GitHub.

## Local one-shot test

```powershell
./scripts/run-autonomous.ps1 -Once -Strict
```

Quick progress summary:

```powershell
./scripts/progress-check.ps1
```

Open the HTML control panel:

```powershell
./scripts/open-dashboard.ps1
```

This gives:
- a button to run daily automation
- a status panel
- a button to test game launcher
- a button to test asset adder launcher
- a text box to save feature/tweak requests into `automation/user-input/feature-requests.md`
- a button to promote saved feature requests into `backlog/tasks.json`
- a button to import `PHASE1_IMPLEMENTATION_PACK.md` tasks into backlog
- a button to import legacy-triage immediate tasks into backlog
- a button to create a local git commit (no push)
- a button to commit and push (with browser confirmation prompt)

## Local continuous mode

```powershell
./scripts/run-autonomous.ps1 -Strict
```

This loops forever every configured interval (default 30 minutes).

## Install Windows auto-run (recommended)

Run PowerShell as Administrator and execute:

```powershell
./scripts/install-autonomous-task.ps1
```

This creates task `CURSE-Autonomous-Loop` and runs one autonomous cycle every 30 minutes.

## Stop auto-run task

```powershell
./scripts/uninstall-autonomous-task.ps1
```

## Where reports go

- Daily summaries: `reports/`
- Bot reports: `reports/bots/`

## Change timing/settings

Edit:
- `automation/automation-config.json`

Then change:
- `loopIntervalMinutes`
- enable/disable bots
- thresholds like `minClearabilityScore`
- `engineTestBot.testCommand` to your real engine test command once available

