# Tiered World Simulation Spec

## Purpose
Define implementation-ready requirements and interfaces for this subsystem.

## Contracts
- Inputs
- Outputs
- Validation path
- Failure modes

## Data Model
- Entity/schema definitions
- Stable ID classes (phase 1 seed):
  - `actorId`
  - `regionId`
  - `jobId`
  - `actionId`

## Runtime
- Tick/update rules
- Authority model
- Phase 1 seed implementation:
  - `engine/sim/tick-loop/tick-loop-service.ps1` executes deterministic tick batches.
  - Deterministic hash is computed from canonically sorted world identity lists.
  - `engine/state/world-ledger/world-ledger-service.ps1` writes canonical world action records.
  - `engine/sim/tiered-world/job-continuity-scheduler.ps1` advances durable jobs across Hot/Warm/Cold/Archive tiers.
  - `engine/sim/tiered-world/tiered-world-continuity-service.ps1` verifies distant tier continuity while local combat is active.
  - Ledger writes must include actor/action/region identities and timestamped event envelope.

## Telemetry and Replay
- Required events
- Phase 1 replay seed:
  - `engine/replay/collector/replay-collector.ps1` captures replay evidence for impactful actions.
  - `tools/replay/query/get-replay-by-id.ps1` provides replay query by event ID and/or player ID.

## Tests
- Unit tests
- Integration tests
- Regression tests
- Seed acceptance checks:
  - Re-running tick loop with same seed input must produce identical `worldStateHash`.
  - World ledger must emit action records with canonical identity fields.
  - Replay collector outputs must be queryable via replay query tool.
