# Authority Validation Spec

## Purpose
Provide the deterministic, authoritative legality path for all impactful actions.
This service is the canonical gate before any action mutates world state.

## Contracts

### Inputs

- `actionEnvelope`:
  - `actionId`
  - `actorId`
  - `actionType` (`move`, `use`, `cast`, `build`, `inventory`, `hybrid`)
  - `scope`
  - `targets`
  - resource declarations
  - replay requirements
  - telemetry tags
- `worldSnapshotRef`:
  - deterministic snapshot handle used by validator at tick `T`
- `policyContext`:
  - jurisdiction, faction policies, progression gates, anti-cheat controls

### Outputs

- `decision`:
  - `allowed` boolean
  - `reasonCodes[]` (from `AUTHORITY_REASON_CODES.md`)
  - `validatorVersion`
  - `evaluatedAtTick`
- `normalizedAction` (only when allowed)
- `replayMetadata` (`required`, `eventTags`, `authorityDecisionId`)

### Validation Path

1. Input integrity checks
2. Scope and ownership checks
3. World-state precondition checks
4. Budget checks (sim + gameplay resources)
5. Interop legality checks (`interop_legality_validator_v1` for hybrid actions)
6. Anti-exploit checks
7. Decision emit + replay metadata emit

### Failure Modes

- `reject`: deterministic rejection with reason code(s)
- `degrade`: permitted with constrained output (future extension)
- `alert`: emit high-severity telemetry for security/abuse domains

## Data Model

### Core Types

- `AuthorityDecision`
- `AuthorityReasonCode`
- `AuthorityReplayMetadata`
- `AuthorityValidationContext`

## Runtime

### Tick/Update Rules

- Validation executes against immutable world snapshot at tick `T`.
- Accepted actions are queued for state application at deterministic order within `T`.
- Rejected actions do not mutate canonical state.

### Authority Model

- Server is single source of truth.
- Client prediction is advisory only and must reconcile to server decision.
- No production gameplay path may bypass authority service.

## Telemetry and Replay

### Required Events

- `authority.validation.requested`
- `authority.validation.allowed`
- `authority.validation.rejected`

### Replay Requirements

- Always include:
  - `actionId`
  - `decision.allowed`
  - `reasonCodes[]`
  - `validatorVersion`
- Replay evidence must remain available even when user-facing replay view is toggled off.

## Tests

### Unit Tests

- Input contract parsing
- Reason-code mapping behavior
- Budget boundary checks

### Integration Tests

- `IT-VAL-001`: core validation gate behavior
- `IT-MGI-001`: hybrid legality path accepted/rejected deterministically
- `IT-MGI-003`: over-budget hybrid action rejected with budget code

### Regression Tests

- deterministic re-run with same seed -> same decisions and reason codes
