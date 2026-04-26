# Yggdrasil Prototype - Phase 1 Implementation Pack

This is the first execution pack for moving from scaffolding/automation into real game-system implementation.

## Goal of Phase 1

Ship a playable technical vertical slice with:
- deterministic core loop
- authoritative action validation
- replay/event evidence
- tiered world continuity
- first demon-lord and apex-entity foundations
- first pass advanced NPC creator contracts

---

## Task 1 - Core Tick and World State Ledger

### Scope
- Implement deterministic server tick loop and canonical world state event ledger.
- Add stable IDs for actor, region, faction, item, and job entities.

### Deliverables
- `engine/sim/tick-loop` module
- `engine/state/world-ledger` module
- schema doc update in `systems/simulation/TIERED_WORLD_SIM_SPEC.md`

### Acceptance Criteria
- Re-running same seeded input yields same world state hash.
- Ledger writes event records for action, economy, diplomacy, and job updates.
- Integration tests mapped in matrix.

---

## Task 2 - Authority Validation Service v1

### Scope
- Add authoritative legality checks for move/use/cast/build/inventory actions.
- Deny invalid actions with reason codes.

### Deliverables
- `engine/net/authority-validation` service
- reason-code contract doc
- interop legality hooks aligned to `MAGITECH_INTEROP_SPEC.md`

### Acceptance Criteria
- Invalid client outcomes never become canonical state.
- Replay includes legality decision metadata.
- Validation test suite passes.
- `IT-MGI-001` legality path passes for hybrid magic/tech action.

---

## Task 3 - Replay Evidence Pipeline v1

### Scope
- Capture contact frames and action outcomes for every impactful interaction.
- Add query endpoint/CLI for replay retrieval by time/player/event ID.

### Deliverables
- `engine/replay/collector`
- `tools/replay/query`

### Acceptance Criteria
- Given event ID, system returns reconstructable contact sequence.
- Replay capture remains on even if user-facing view is toggled off.

---

## Task 4 - Tiered World Simulation Continuity

### Scope
- Implement Hot/Warm/Cold/Archive tiers with durable job continuity.
- Ensure distant shipments and jobs continue while local combat happens.

### Deliverables
- tier transition rules
- background job scheduler

### Acceptance Criteria
- Distant shipment test never freezes during local combat test.
- Tier transitions preserve state without data loss.

---

## Task 5 - Construction Magic and Build Permission v1

### Scope
- Gate build complexity/speed/stability by Construction Magic level.
- Add deconstruction gap rule (~5 levels).

### Deliverables
- build permission evaluator
- deconstruction evaluator
- first shared magic/tech build interaction rules referenced from `MAGITECH_INTEROP_SPEC.md`

### Acceptance Criteria
- CM level correctly affects allowed blueprint complexity and manifest speed.
- Deconstruction is blocked outside allowed level-gap policy.
- At least one build flow supports both arcane and device-side modifiers via shared validator path.

---

## Task 6 - Demon Lord Authority Framework

### Scope
- Create Demon Lord entity class with domain control and minion command channels.
- Add temperament-driven behavior profile hooks.

### Deliverables
- demon-lord entity schema
- minion command interface
- temperament profile schema

### Acceptance Criteria
- Demon Lord can control configured minion groups and apply domain effects.
- Temperament profile modifies diplomacy/hostility/command style outcomes.

---

## Task 7 - Apex Entity Framework (Legendary, God-Killer, Interdimensional)

### Scope
- Add apex entity archetype system with custom dimensions/armies/signature powers.
- Implement rule hooks for exclusive magic/tech grammars.
- Ensure exclusive grammars still execute through shared interop runtime contracts.

### Deliverables
- apex archetype registry
- dimension ownership contract
- exclusive ability grammar hooks

### Acceptance Criteria
- At least one entity from each category can be instantiated and simulated.
- Each category supports distinct balance/counterplay envelope.
- Exclusive grammar actions preserve interop legality, budget, and replay requirements.

---

## Task 8 - Advanced NPC Creator v1 (Data + Validation)

### Scope
- Add NPC creator contract allowing power/temperament/class/cross-class customization.
- Add strict legality and budget validation before spawn/activation.

### Deliverables
- creator input schema
- validator pipeline
- audit tags (creator/version/package)

### Acceptance Criteria
- Creator can define deep NPC spec and receive deterministic validator output.
- Illegal/exploit NPC specs are rejected with clear reasons.

---

## Task 9 - Live Content Promotion Gates for New Entity Systems

### Scope
- Ensure demon/apex/NPC-creator content passes same live-content gating as all other content.
- Add canary + rollback for entity packages.

### Deliverables
- content package validator extensions
- rollback manifest support

### Acceptance Criteria
- Entity package fails promotion if budget or legality checks fail.
- Rollback restores prior known-good package state.

---

## Task 10 - Dashboard v2: Product Control Surface

### Scope
- Add one-click "Run Daily + Promote Features" button.
- Add widget showing top 10 backlog tasks and latest goal-alignment failures.
- Add interop status indicator (magic/tech/hybrid validator pass rates from latest run).

### Deliverables
- dashboard endpoint updates
- dashboard UI updates
- interop health summary endpoint

### Acceptance Criteria
- Single click runs daily cycle then promotes features.
- Dashboard clearly shows PASS/FAIL and missing alignment signals.
- Dashboard exposes latest `IT-MGI-*` results and interop validator failures.

---

## Execution Order and Timebox

- Week 1: Tasks 1-3
- Week 2: Tasks 4-5
- Week 3: Tasks 6-7
- Week 4: Tasks 8-10

## Definition of Done (Phase 1)

- All 10 task acceptance criteria pass.
- `progress-check.ps1` reports Orchestrator PASS and Goal Alignment PASS.
- Interaction matrix updated for every new cross-system behavior.
- Replay + authority checks cover newly added systems.
- `MAGITECH_INTEROP_SPEC.md` validators and Phase 1 seed tests (`IT-MGI-001`..`IT-MGI-004`) are wired and passing.

