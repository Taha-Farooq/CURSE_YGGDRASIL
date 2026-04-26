# CURSE System Interaction Matrix Template (v1)

Use this document to keep subsystem interactions explicit and testable. Update this matrix whenever a feature changes cross-system behavior.

## How To Use

- One row per directional interaction (`source -> target`).
- If a subsystem both reads and writes another, add two rows.
- Keep identifiers stable so CI can validate coverage.
- Link each row to at least one integration test ID.

---

## Subsystem Catalog (Baseline)

- `combat_runtime`
- `arcane_tech_runtime`
- `progression_and_evolution`
- `building_and_construction_magic`
- `crafting_and_factory`
- `inventory_storage_logistics`
- `npc_mob_ai_learning`
- `factions_civilizations_diplomacy`
- `economy_and_markets`
- `dungeons_and_encounters`
- `artifacts_world_uniques`
- `replay_telemetry_moderation`
- `live_content_pipeline`
- `bot_orchestrator`

---

## Matrix Columns

- `interaction_id`: unique ID (e.g., `INT-0001`)
- `source_subsystem`
- `target_subsystem`
- `read_fields`: canonical fields read by source from target state
- `write_fields`: fields source writes that affect target
- `trigger`: what starts this interaction (tick/event/player action/batch)
- `cadence`: realtime / per_tick / batched / event_driven
- `authority`: server / client_predicted / toolchain
- `validation_path`: validator IDs or service names
- `failure_mode`: reject / retry / degrade / fallback / alert
- `telemetry_events`: event names emitted
- `replay_coverage`: yes/no and event IDs required
- `integration_test_ids`: list of required tests
- `owner`: team/role accountable
- `notes`

---

## Matrix Entries (Fill In)

| interaction_id | source_subsystem | target_subsystem | read_fields | write_fields | trigger | cadence | authority | validation_path | failure_mode | telemetry_events | replay_coverage | integration_test_ids | owner | notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| INT-0001 | combat_runtime | progression_and_evolution | entity_level, damage_tags, kill_context | xp_delta, mastery_progress, death_penalties | combat_resolution_event | event_driven | server | action_legality_v1, progression_rules_v1 | reject_and_alert | combat.hit.confirmed, progression.xp.applied | yes:event_ids_required | IT-CORE-001, IT-PROG-003 | gameplay_eng | Baseline kill-to-XP pipeline |
| INT-0002 | dungeons_and_encounters | economy_and_markets | dungeon_control_state, drop_table_version | regional_supply_delta, price_index_delta | dungeon_state_tick | per_tick | server | economy_balance_guard_v1 | degrade_and_alert | economy.region.updated | no | IT-ECO-004 | world_sim_eng | Dungeon hubs affect regional economy |
| INT-0003 | factions_civilizations_diplomacy | arcane_tech_runtime | concordance_score, law_state | high_tier_cast_permission | policy_change_event | event_driven | server | magic_gate_validator_v1 | reject | diplomacy.policy.applied, magic.gate.changed | yes:event_ids_required | IT-POL-006, IT-MAG-009 | systems_design | Social policy influences high-tier magic |
| INT-0004 | inventory_storage_logistics | combat_runtime | ammo_state, consumable_state, transport_status | availability_flags, cooldown_gates | player_action_use_item | realtime | server | inventory_authority_v1 | reject | inventory.item.used, combat.action.gated | yes:event_ids_required | IT-INV-002 | netcode_eng | Canonical authority for item use |

---

## Required End-To-End Scenario Mapping

Map each required scenario from `REQUIREMENTS.md` to matrix rows and tests.

| scenario_id | scenario_description | interaction_ids | test_ids | status |
|---|---|---|---|---|
| SCN-001 | War/logistics shortages alter military readiness and politics | INT-XXXX, INT-YYYY | IT-WAR-001, IT-LOG-003 | planned |
| SCN-002 | Dungeon control alters economy and guild demand | INT-0002, INT-ZZZZ | IT-ECO-004, IT-GUILD-002 | in_progress |
| SCN-003 | Social policy alters migration/diplomacy/magic gates | INT-0003, INT-AAAA | IT-POL-006, IT-MAG-009 | planned |
| SCN-004 | Live-authored spell/device respects authority and legality | INT-BBBB, INT-CCCC | IT-LIVE-005, IT-VAL-001 | planned |

---

## CI Contract (Enforcement Checklist)

- [ ] Every subsystem in catalog appears in at least one inbound and outbound interaction.
- [ ] Every interaction has at least one integration test.
- [ ] Every interaction declares authority and validation path.
- [ ] Every high-impact interaction includes replay/telemetry coverage.
- [ ] PRs changing cross-system behavior update this matrix and linked tests.

