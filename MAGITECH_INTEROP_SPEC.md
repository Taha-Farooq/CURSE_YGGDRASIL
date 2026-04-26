# Yggdrasil Prototype - Magic/Tech Interop Spec (v1)

This spec defines the mandatory interoperability contract between the arcane and technology systems.
It is intended to make the magic system dynamic, simulation-driven, and fully compatible with the tech stack from day one.

## 1) Purpose

- Ensure magic and tech are not isolated subsystems.
- Enforce one shared runtime model for world state change.
- Preserve high convenience for players while enabling deep emergent interactions.

## 2) Core Interop Rule (Mandatory)

All impactful magic and tech effects MUST compile into the same canonical world-state operation model:

- read world facts
- evaluate legality and budget
- apply world deltas
- emit replay/telemetry evidence

No subsystem may bypass this path for production gameplay effects.

## 3) Shared Runtime Contract

## 3.1) Shared Fact Space

Magic and tech must read/write a shared fact registry with typed predicates/components (examples):

- `Heat(entity_or_cell, value)`
- `Charge(entity_or_cell, value)`
- `Integrity(structure, value)`
- `Affinity(entity, tag)`
- `Signal(source, target, channel)`
- `AuthorityScope(actor, scope_tag)`
- `Stability(zone_or_construct, value)`

Additive domain facts are allowed, but equivalent concepts must not be duplicated under separate magic-only and tech-only keys.

## 3.2) Shared Execution Stages

Every effect (spell cast, device activation, hybrid trigger) executes through:

1. Target resolution and scope checks.
2. Legality validation (authority, progression, ownership, policy).
3. Cost/budget evaluation (sim cost + gameplay resource cost).
4. Delta planning and conflict detection.
5. Delta application to canonical state.
6. Axiom/law propagation pass.
7. Replay + telemetry emission.

## 4) Dynamic Behavior Requirements

- Outcomes must depend on context, not static templates only:
  - environment state
  - zone policies
  - faction status
  - species traits
  - infrastructure topology
- The same input action can produce different results under different fact conditions.
- Contradictory or over-budget actions must fail deterministically with reason codes.

## 5) Resource and Cost Interop

Magic-side costs and tech-side costs must coexist under one budget framework:

- magic examples: mana, HP risk, XP strain
- tech examples: fuel, materials, maintenance, cooldown cycles
- shared sim budget examples: CPU budget class, memory/event budget, network event budget

Hybrid effects must declare all participating cost channels.

## 6) Axioms and Device Laws

- World axioms apply to both systems (e.g., heat propagation, conductivity, instability).
- Device laws can modulate magic (amplify, dampen, route, isolate).
- Spell laws can modulate tech (power, jam, shield, corrupt, reconfigure) within legality bounds.
- Axiom application must be deterministic and replay-reconstructable.

## 7) Hybrid Composition Requirements

The runtime must support composition patterns without custom one-off code paths:

- magic powering devices
- devices shaping spell propagation
- runic automation controllers
- anti-magic tech grids
- spell-driven factory modifiers

At least one validated use case per pattern must exist before end of Phase 2.

## 8) Counterplay Symmetry

Both paradigms need robust counters:

- tech counters to magic: interference fields, sealers, grounding networks, interrupt tooling
- magic counters to tech: nullification wards, overload pulses, entropy spikes, spoofed command states

No top-tier feature may ship without at least one realistic counter channel from the opposite paradigm.

## 9) Convenience and UX Constraints

To keep gameplay convenient while preserving depth:

- provide quick-cast / quick-activate slots for both magic and devices
- provide preset generation for common hybrid combos
- provide clear failure reasons and fallback suggestions
- keep advanced graph editing optional, not mandatory for baseline viability

Convenience layers must compile to the same shared runtime model (no hidden bypass).

## 10) Validation and Testing Requirements

## 10.1) Required Validators

- `interop_legality_validator_v1`
- `interop_budget_guard_v1`
- `hybrid_conflict_validator_v1`
- `axiom_propagation_validator_v1`

## 10.2) Required Integration Tests (Phase 1 Seed)

- `IT-MGI-001`: magic-powered device executes through shared legality and replay path.
- `IT-MGI-002`: tech suppression field alters spell outcome deterministically.
- `IT-MGI-003`: hybrid combo fails cleanly when budget exceeds allowed envelope.
- `IT-MGI-004`: same hybrid action in two environments yields expected context-sensitive differences.

## 10.3) Replay/Telemetry Minimums

Every interop action must log:

- action ID, actor IDs, target scope
- validator pass/fail and reason codes
- applied deltas and post-axiom deltas
- resource cost breakdown
- interop tags (`magic`, `tech`, `hybrid`)

## 11) Governance

- All Phase 1+ PRs touching magic or tech must reference this spec.
- Interaction matrix updates are mandatory for any new interop read/write path.
- Non-compliant features are blocked from promotion.

