# Yggdrasil Prototype

Yggdrasil Prototype is an early-stage foundation for a large-scale, persistent simulation RPG that unifies first-person action, magic-tech systems, world simulation, and geopolitical sandbox dynamics.

## Current Focus

- Requirements-first development
- Autonomous validation and bot-assisted QA loops
- Structured feedback ingestion and triage contracts
- Cross-system interaction mapping for long-term cohesion

## Local Automation Commands

Run one autonomous cycle:

```powershell
./scripts/run-autonomous.ps1 -Once -Strict
```

Run continuous local automation:

```powershell
./scripts/run-autonomous.ps1 -Strict
```

Install Windows scheduled autonomous loop:

```powershell
./scripts/install-autonomous-task.ps1
```

Open the HTML control panel (button-based daily run + feature input):

```powershell
./scripts/open-dashboard.ps1
```

Ensure launcher executables are up to date:

```powershell
./scripts/ensure-program-exes.ps1
```

## Key Project Docs

- `REQUIREMENTS.md`
- `INTERACTION_MATRIX.md`
- `FEEDBACK_SCHEMA.json`
- `AUTONOMOUS_SETUP.md`
- `ONE_PERSON_TEAM_LOOP.md`

## Folder Layout (Separation of Concerns)

- `programs/game/` -> game runtime launcher and game-facing files
- `programs/asset-adder/` -> asset/content adder launcher and tool files
- `automation/`, `bots/`, `scripts/` -> autonomous development and validation system

## License

This project is licensed under the Apache License 2.0. See `LICENSE`.

