# Authority Reason Codes v1.0

<!-- AUTO-GENERATED: Run scripts/sync-authority-reason-codes-doc.ps1 -->

This document defines canonical reason codes returned by `engine/net/authority-validation`.
Machine-readable source of truth: `systems/networking/AUTHORITY_REASON_CODES.json`.

## Purpose

- Ensure every rejected action has a deterministic machine-readable reason.
- Keep replay, telemetry, and moderation tooling aligned to one reason-code taxonomy.

## Format

- Prefix: `AUTH-`
- Structure: `AUTH-<domain>-<number>`
- Example: `AUTH-SCOPE-001`

## Codes

| code | domain | meaning |
|---|---|---|
| `AUTH-INPUT-001` | INPUT | action payload missing required IDs or type |
| `AUTH-INPUT-002` | INPUT | unsupported action type |
| `AUTH-SCOPE-001` | SCOPE | actor not authorized for requested scope |
| `AUTH-SCOPE-002` | SCOPE | ownership mismatch for target entity |
| `AUTH-STATE-001` | STATE | required world preconditions not met |
| `AUTH-BUDGET-001` | BUDGET | simulation budget exceeded |
| `AUTH-BUDGET-002` | BUDGET | gameplay resource budget exceeded |
| `AUTH-SEC-001` | SEC | action flagged by anti-exploit policy |
| `AUTH-INTEROP-001` | INTEROP | missing shared world-fact read/write declaration |
| `AUTH-INTEROP-002` | INTEROP | missing replay-required marker for interop action |
| `AUTH-INTEROP-003` | INTEROP | missing required interop telemetry tags |
| `AUTH-INTEROP-004` | INTEROP | hybrid action missing dual-channel cost declaration |

## Mapping to Interop Validator

The authority service maps `INT-LEG-*` legality failures to canonical `AUTH-*` codes via the JSON contract:

- `INT-LEG-001-MISSING_IDENTITY` -> `AUTH-INPUT-001`
- `INT-LEG-002-INVALID_ACTION_TYPE` -> `AUTH-INPUT-002`
- `INT-LEG-003-INVALID_SCOPE` -> `AUTH-SCOPE-001`
- `INT-LEG-004-FACT_ACCESS_EMPTY` -> `AUTH-INTEROP-001`
- `INT-LEG-005-REPLAY_REQUIRED` -> `AUTH-INTEROP-002`
- `INT-LEG-006-MISSING_INTEROP_TAGS` -> `AUTH-INTEROP-003`
- `INT-LEG-007-HYBRID_COST_CHANNELS_MISSING` -> `AUTH-INTEROP-004`
- `INT-LEG-008-NO_COST_CHANNEL` -> `AUTH-BUDGET-002`
- `INT-LEG-009-MISSING_SIM_BUDGET` -> `AUTH-BUDGET-001`
- `INT-LEG-010-SIM_BUDGET_EXCEEDED` -> `AUTH-BUDGET-001`

Fallback code for unmapped reasons: `AUTH-STATE-001`

## Contract Rules

- Every rejection MUST include at least one reason code.
- Reason codes MUST be stable across versions unless explicitly deprecated.
- Replay capture MUST persist reason codes even when user replay UI is disabled.
- Telemetry event `authority.validation.rejected` MUST include:
  - action ID
  - actor ID
  - reason codes[]
  - validator version

Last generated from JSON contract version `1.0` at `2026-04-26T00:00:00Z`.

