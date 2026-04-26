# Interaction Replay Spec

## Purpose
Define replay-grade evidence requirements for all impactful gameplay actions, including magitech hybrid paths.

## Contracts

### Inputs

- authority decision metadata
- action envelope
- contact/result events
- runtime delta summaries

### Outputs

- reconstructable replay records keyed by:
  - action ID
  - actor ID
  - timestamp/tick
  - region or encounter scope
- replay query payloads for tooling/dashboard

### Validation Path

1. Validate replay-required flag presence
2. Validate event linkage (`actionId` and `authorityDecisionId`)
3. Validate required tags and reason-code attachment
4. Persist immutable replay record

### Failure Modes

- reject replay write (with alert)
- quarantine incomplete evidence bundles

## Data Model

### Core Types

- `ReplayActionRecord`
- `ReplayAuthorityDecisionRecord`
- `ReplayDeltaRecord`
- `ReplayQueryResult`

## Runtime

### Tick/Update Rules

- Replay writes occur in same tick cycle as authority decision application.
- Missing replay-required metadata must fail validation in strict mode.

### Authority Model

- Replay is downstream of authority and runtime results; it never authors truth.
- Replay stores evidence, not gameplay decisions.

## Telemetry and Replay

### Required Events

- `replay.capture.requested`
- `replay.capture.persisted`
- `replay.capture.failed`
- `replay.query.executed`

### Required Fields for Hybrid Actions

- `decision.reasonCodes[]`
- `interop tags`
- `pre/post-axiom delta summaries`
- `replayEventCount`

## Tests

### Unit Tests

- replay schema validation
- reason-code attachment checks

### Integration Tests

- `IT-RPL-003`: replay chain reconstructs authority and outcome links
- `SCN-005`: hybrid action replay evidence includes interop tags and decision linkage

### Regression Tests

- identical seed and inputs produce identical replay record hashes
