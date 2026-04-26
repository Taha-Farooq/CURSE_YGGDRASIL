# Interaction Matrix Contract Summary v1.0

<!-- AUTO-GENERATED: Run scripts/sync-interaction-matrix-contract-doc.ps1 -->

Machine-readable source of truth: `systems/integration/INTERACTION_MATRIX_CONTRACT.json`.

## Contract Overview

- Interactions: 13
- Scenarios: 5
- Required interaction IDs: INT-0013
- Required scenario IDs: SCN-005

## Interactions

| interaction_id | source_subsystem | target_subsystem | integration_test_ids | owner |
|---|---|---|---|---|
| `INT-0001` | combat_runtime | progression_and_evolution | IT-CORE-001, IT-PROG-003 | gameplay_eng |
| `INT-0002` | dungeons_and_encounters | economy_and_markets | IT-ECO-004 | world_sim_eng |
| `INT-0003` | factions_civilizations_diplomacy | arcane_tech_runtime | IT-POL-006, IT-MAG-009 | systems_design |
| `INT-0004` | inventory_storage_logistics | combat_runtime | IT-INV-002 | netcode_eng |
| `INT-0005` | building_and_construction_magic | factions_civilizations_diplomacy | IT-BLD-004, IT-POL-010 | world_sim_eng |
| `INT-0006` | crafting_and_factory | economy_and_markets | IT-IND-003, IT-ECO-007 | economy_eng |
| `INT-0007` | inventory_storage_logistics | factions_civilizations_diplomacy | IT-LOG-005, IT-POL-004 | logistics_eng |
| `INT-0008` | npc_mob_ai_learning | economy_and_markets | IT-AI-002, IT-ECO-009 | ai_systems |
| `INT-0009` | live_content_pipeline | arcane_tech_runtime | IT-LIVE-005, IT-VAL-001 | tools_eng |
| `INT-0010` | bot_orchestrator | live_content_pipeline | IT-BOT-001, IT-LIVE-008 | qa_automation |
| `INT-0011` | replay_telemetry_moderation | validation_and_anticheat | IT-RPL-003, IT-SEC-002 | trust_safety |
| `INT-0012` | progression_and_evolution | dungeons_and_encounters | IT-DGN-006, IT-PROG-010 | gameplay_eng |
| `INT-0013` | arcane_runtime | tech_runtime | IT-MGI-001, IT-MGI-002, IT-MGI-003, IT-MGI-004 | systems_design |

## Scenarios

| scenario_id | interaction_ids | test_ids | status |
|---|---|---|---|
| `SCN-001` | INT-0007, INT-0005 | IT-LOG-005, IT-POL-010 | planned |
| `SCN-002` | INT-0002, INT-0012 | IT-ECO-004, IT-DGN-006 | planned |
| `SCN-003` | INT-0003, INT-0008 | IT-POL-006, IT-AI-002 | planned |
| `SCN-004` | INT-0009, INT-0010 | IT-LIVE-005, IT-VAL-001 | planned |
| `SCN-005` | INT-0013, INT-0011 | IT-MGI-002, IT-MGI-004, IT-RPL-003 | planned |

Last generated from JSON contract version `1.0` at `2026-04-26T00:00:00Z`.

