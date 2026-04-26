# CURSE System Interaction Matrix (v1 Seed)

This is the first concrete matrix based on current requirements. Expand this file on every feature PR.

| interaction_id | source_subsystem | target_subsystem | read_fields | write_fields | trigger | cadence | authority | validation_path | failure_mode | telemetry_events | replay_coverage | integration_test_ids | owner | notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| INT-0001 | combat_runtime | progression_and_evolution | entity_level, damage_tags, kill_context | xp_delta, mastery_progress, death_penalties | combat_resolution_event | event_driven | server | action_legality_v1, progression_rules_v1 | reject_and_alert | combat.hit.confirmed, progression.xp.applied | yes:event_ids_required | IT-CORE-001, IT-PROG-003 | gameplay_eng | kill -> XP/loss application |
| INT-0002 | dungeons_and_encounters | economy_and_markets | dungeon_control_state, drop_table_version | regional_supply_delta, price_index_delta | dungeon_state_tick | per_tick | server | economy_balance_guard_v1 | degrade_and_alert | economy.region.updated | no | IT-ECO-004 | world_sim_eng | dungeon hubs drive economy |
| INT-0003 | factions_civilizations_diplomacy | arcane_tech_runtime | concordance_score, law_state | high_tier_cast_permission | policy_change_event | event_driven | server | magic_gate_validator_v1 | reject | diplomacy.policy.applied, magic.gate.changed | yes:event_ids_required | IT-POL-006, IT-MAG-009 | systems_design | policy gates top magic |
| INT-0004 | inventory_storage_logistics | combat_runtime | ammo_state, consumable_state, transport_status | availability_flags, cooldown_gates | player_action_use_item | realtime | server | inventory_authority_v1 | reject | inventory.item.used, combat.action.gated | yes:event_ids_required | IT-INV-002 | netcode_eng | canonical inventory gate |
| INT-0005 | building_and_construction_magic | factions_civilizations_diplomacy | construction_scale, fortification_state, territory_claims | threat_perception_delta, border_tension_delta | structure_manifested_event | event_driven | server | build_legality_v1 | reject_and_alert | build.manifested, diplomacy.tension.changed | yes:event_ids_required | IT-BLD-004, IT-POL-010 | world_sim_eng | megabuilds affect politics |
| INT-0006 | crafting_and_factory | economy_and_markets | production_jobs, quality_tiers, labor_state | commodity_output, export_capacity, market_pressure | factory_tick | per_tick | server | factory_budget_guard_v1 | degrade | factory.batch.completed, economy.commodity.changed | no | IT-IND-003, IT-ECO-007 | economy_eng | industrial output impacts markets |
| INT-0007 | inventory_storage_logistics | factions_civilizations_diplomacy | route_status, embargo_flags, convoy_losses | trade_trust_delta, treaty_breach_flags | convoy_resolution_event | event_driven | server | treaty_and_route_validator_v1 | retry_then_alert | logistics.route.updated, diplomacy.trade.changed | yes:event_ids_required | IT-LOG-005, IT-POL-004 | logistics_eng | trade failures affect diplomacy |
| INT-0008 | npc_mob_ai_learning | economy_and_markets | job_assignments, innovation_scores, guild_affinity | labor_efficiency_delta, invention_supply_delta | daily_ai_progress_tick | batched | server | ai_progression_guard_v1 | degrade | ai.skill.progressed, economy.innovation.changed | no | IT-AI-002, IT-ECO-009 | ai_systems | NPC learning drives economy |
| INT-0009 | live_content_pipeline | arcane_tech_runtime | content_manifest, generated_spell_ir | enabled_content_flags, runtime_registry_updates | content_promote_request | event_driven | toolchain+server | live_content_validator_v1, runtime_compiler_v1 | block | content.validation.completed, content.promoted | yes:event_ids_required | IT-LIVE-005, IT-VAL-001 | tools_eng | no direct prod without gates |
| INT-0010 | bot_orchestrator | live_content_pipeline | bot_findings, severity_scores, reproduction_artifacts | promotion_block_flags, required_fix_tasks | bot_sweep_completed | event_driven | toolchain | bot_policy_guard_v1 | block_and_page | bot.report.created, release.blocked | no | IT-BOT-001, IT-LIVE-008 | qa_automation | bots can halt release |
| INT-0011 | replay_telemetry_moderation | validation_and_anticheat | action_events, contact_frames, timing_data | cheat_flags, dispute_resolution_state | post_match_processing | batched | server | replay_integrity_validator_v1 | alert_and_quarantine | replay.processed, anticheat.flagged | yes:full_chain | IT-RPL-003, IT-SEC-002 | trust_safety | replay supports anti-cheat |
| INT-0012 | progression_and_evolution | dungeons_and_encounters | player_level_band, milestone_state | dungeon_rule_variant, boss_profile_variant | dungeon_entry_event | event_driven | server | progression_gate_validator_v1 | reject | dungeon.entry.validated, progression.gate.checked | yes:event_ids_required | IT-DGN-006, IT-PROG-010 | gameplay_eng | adaptive mind-dungeon rules |

## End-To-End Scenario Mapping

| scenario_id | scenario_description | interaction_ids | test_ids | status |
|---|---|---|---|---|
| SCN-001 | War/logistics shortages alter military readiness and politics | INT-0007, INT-0005 | IT-LOG-005, IT-POL-010 | planned |
| SCN-002 | Dungeon control alters economy and guild demand | INT-0002, INT-0012 | IT-ECO-004, IT-DGN-006 | planned |
| SCN-003 | Social policy alters migration/diplomacy/magic gates | INT-0003, INT-0008 | IT-POL-006, IT-AI-002 | planned |
| SCN-004 | Live-authored spell/device respects authority and legality | INT-0009, INT-0010 | IT-LIVE-005, IT-VAL-001 | planned |

