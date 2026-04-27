# Yggdrasil Prototype - Phase 2 Implementation Pack

This pack starts immediately after Phase 1 completion and focuses on shipping a playable systems-synergy slice with stronger world agency.

## Goal of Phase 2

Ship a coherent mid-loop slice with:
- durable progression pressure (mind-dungeon + adaptive encounters)
- economy/logistics consequences tied to conflict and policy
- controlled live-content rollout of entity packages
- NPC creator and apex/demon systems integrated into world simulation
- phase-level acceptance evidence comparable to Phase 1

---

## Task 1 - Mind Dungeon Gate Runtime v1

### Scope
- Implement first pass of mind-dungeon unlock gate and adaptive encounter profile binding.

### Deliverables
- mind-dungeon gate evaluator
- adaptive encounter profile selector

### Acceptance Criteria
- Gate correctly allows/denies entry by level/milestone.
- Encounter profile changes with player progression state.

---

## Task 2 - Economy/Logistics Shock Propagation v1

### Scope
- Propagate route disruption and convoy loss into market pressure and regional supply state.

### Deliverables
- logistics shock propagation service
- economy pressure update pipeline

### Acceptance Criteria
- Route failure produces deterministic economy deltas.
- Economy deltas are replay/audit tagged.

---

## Task 3 - Policy-to-Magic Stability Coupler v1

### Scope
- Connect diplomacy/policy changes to high-tier magic stability permissions.

### Deliverables
- policy stability coupler
- stability gate reason-code outputs

### Acceptance Criteria
- Policy shift updates stability gate state deterministically.
- Rejected casts expose clear reason codes.

---

## Task 4 - NPC Creator Runtime Spawn Path v1

### Scope
- Move validated NPC creator specs into controlled runtime spawn path.

### Deliverables
- creator spawn activation service
- runtime budget guard for created NPCs

### Acceptance Criteria
- Valid specs spawn successfully with audit lineage.
- Over-budget specs fail before activation.

---

## Task 5 - Demon Lord Domain Expansion Loop v1

### Scope
- Add demon-lord domain expansion tick behavior with minion command feedback.

### Deliverables
- domain expansion scheduler
- minion response + domain effect propagation

### Acceptance Criteria
- Domain expansion modifies world state according to temperament/command style.
- Expansion events are recorded in ledger and replay streams.

---

## Task 6 - Apex Encounter Injection v1

### Scope
- Introduce apex archetype encounters into selected regions/dimensions under budget and legality guards.

### Deliverables
- apex encounter injector
- dimension ownership enforcement hook

### Acceptance Criteria
- Eligible apex entities are injected by registry rules.
- Ownership contract violations are rejected with traceable reasons.

---

## Task 7 - Live Entity Package Canary Controller v1

### Scope
- Add explicit canary rollout controller for demon/apex/npc packages.

### Deliverables
- canary rollout state machine
- rollback trigger policy

### Acceptance Criteria
- Canary state transitions are deterministic and auditable.
- Rollback trigger restores prior package cleanly.

---

## Task 8 - Route Clearability Signal Integration v1

### Scope
- Integrate route-clearability signals directly into prioritization for world updates and fixes.

### Deliverables
- clearability signal ingestor
- weighted route risk scorer

### Acceptance Criteria
- High-risk routes are ranked and surfaced automatically.
- Risk signals can be traced to source reports.

---

## Task 9 - Phase 2 Dashboard Controls v1

### Scope
- Add Phase 2-specific controls/status cards to dashboard.

### Deliverables
- phase2 acceptance report card
- canary/rollback state card

### Acceptance Criteria
- Dashboard displays latest phase2 acceptance status and key blockers.
- Operator can refresh phase2 state without CLI.

---

## Task 10 - Phase 2 Acceptance Evidence Pack

### Scope
- Establish acceptance evidence runner equivalent to Phase 1 pattern.

### Deliverables
- `scripts/phase2-acceptance-report.ps1`
- evidence artifact under `reports/`

### Acceptance Criteria
- All Phase 2 task checks are machine-runnable.
- Report emits pass/fail by task and strict mode blocks on failures.

---

## Execution Order and Timebox

- Week 1: Tasks 1-3
- Week 2: Tasks 4-6
- Week 3: Tasks 7-9
- Week 4: Task 10 + hardening

## Definition of Done (Phase 2)

- All 10 Phase 2 task acceptance criteria pass.
- `progress-check.ps1` reports Orchestrator PASS and Goal Alignment PASS.
- `phase2-acceptance-report.ps1 -Strict` passes and writes evidence artifact.
- No regression in Phase 1 acceptance checks.
