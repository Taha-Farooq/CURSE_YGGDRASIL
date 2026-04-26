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
- `automation/automation-config.json` -> controls intervals and bot settings.
- `.github/workflows/autonomous-sweep.yml` -> hourly cloud automation on GitHub.

## Local one-shot test

```powershell
./scripts/run-autonomous.ps1 -Once -Strict
```

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

