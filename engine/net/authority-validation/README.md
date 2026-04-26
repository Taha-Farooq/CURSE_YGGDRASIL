# Authority Validation Service (Scaffold v1)

This folder is the executable scaffold for Phase 1 Task 2:

- authoritative legality checks
- deterministic decision output
- canonical reason-code mapping
- replay metadata emission

Current entrypoint:

- `authority-validation-service.ps1`

Current behavior:

- wraps `scripts/interop-legality-validator.ps1`
- maps `INT-LEG-*` codes to canonical `AUTH-*` codes
- returns normalized authority decision payload
