# Arcane Runtime Spec

## Purpose
Define the runtime contract for composable spell execution that interoperates with the technology runtime via shared world facts.

## Contracts

### Inputs

- `spellActionEnvelope`
  - action metadata
  - spell IR payload
  - target scope and selectors
  - resource declarations
- `worldSnapshotRef`
- `axiomSetRef`
- optional `deviceContext` for hybrid execution

### Outputs

- `runtimeDecision` (`allowed`, `reasonCodes[]`)
- `plannedWorldDeltas[]`
- `postAxiomWorldDeltas[]`
- `resourceCostBreakdown`
- `replayTags`

### Validation Path

1. Spell IR parse + structural validation
2. Authority and progression gate checks
3. Interop legality checks for hybrid actions
4. Budget checks and contradiction checks
5. Delta planning
6. Axiom propagation pass

### Failure Modes

- `fizzle`: invalid or contradictory spell formula
- `reject`: authority/interop/budget blocked
- `backlash`: legal but high-risk cast side effect (future extension)

## Data Model

### Core Types

- `SpellActionEnvelope`
- `SpellFormulaIR`
- `WorldFactDelta`
- `ArcaneRuntimeDecision`
- `AxiomPropagationResult`

## Runtime

### Tick/Update Rules

- Spell planning executes deterministically on server tick.
- Axiom propagation executes immediately after base deltas are planned.
- Runtime must not apply deltas outside authority-approved action envelope.

### Authority Model

- Arcane runtime is not authoritative alone.
- It depends on `engine/net/authority-validation` for final legality.
- For hybrid spells/devices, arcane and tech branches must converge into the same canonical delta path.

## Telemetry and Replay

### Required Events

- `arcane.cast.requested`
- `arcane.cast.resolved`
- `arcane.cast.rejected`
- `arcane.axiom.propagated`

### Replay Requirements

- Include:
  - spell action ID
  - formula hash
  - planned deltas
  - post-axiom deltas
  - final decision and reason codes
  - interop tags (`magic`, `tech`, `hybrid`) when applicable

## Tests

### Unit Tests

- formula parser and contradiction detection
- deterministic axiom propagation
- resource cost aggregation

### Integration Tests

- `IT-MGI-002`: tech suppression modifies arcane-hybrid resolved effect
- `IT-MGI-004`: environmental context changes resolved hybrid outcome
- `SCN-005`: legality + environment variation + replay evidence chain

### Regression Tests

- same action and world snapshot must produce identical resolved deltas and decision metadata
