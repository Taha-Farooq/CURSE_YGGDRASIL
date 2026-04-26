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

## Key Project Docs

- `REQUIREMENTS.md`
- `INTERACTION_MATRIX.md`
- `FEEDBACK_SCHEMA.json`
- `AUTONOMOUS_SETUP.md`
- `ONE_PERSON_TEAM_LOOP.md`

## License

This project is licensed under the Apache License 2.0. See `LICENSE`.

