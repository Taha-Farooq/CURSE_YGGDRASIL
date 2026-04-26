# Autonomous Team Mode

This project now supports a self-growing automation layer that can plan and scaffold systems continuously.

## Bot Roles

- `task-planner-bot`: creates/updates backlog tasks from `REQUIREMENTS.md`.
- `system-builder-bot`: scaffolds core subsystem specification files under `systems/`.
- `implementation-bot`: generates implementation plans under `implementation-plans/`.
- `team-growth-bot`: adds virtual specialist roles under `team/roles.json` as workload rises.
- Existing QA/validation bots remain in the loop and gate unsafe changes.

## Safety Model

- Automation is scaffold/plan-first, not blind production code rewrites.
- Validation bot + quality gate run every autonomous cycle.
- Reports are written to `reports/bots/` for auditability.
- You can disable or tune any bot in `automation/automation-config.json`.

## How To Run

One-shot:

```powershell
./scripts/run-autonomous.ps1 -Once -Strict
```

Continuous:

```powershell
./scripts/run-autonomous.ps1 -Strict
```

## Where Outputs Appear

- Backlog tasks: `backlog/tasks.json`
- System specs: `systems/**`
- Implementation plans: `implementation-plans/**`
- Team roles: `team/roles.json`
- Bot reports: `reports/bots/**`

