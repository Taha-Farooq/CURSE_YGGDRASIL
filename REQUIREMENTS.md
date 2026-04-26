# CURSE - Master Requirements (v1)

This document defines the mandatory requirements for the project and is the source of truth for engineering and design implementation.

## 1) Product Vision

- Build a persistent 3D first-person sandbox RPG/sim with smooth FPS gameplay.
- Core loop is a synergy of magic, technology, building, automation, politics, and war.
- World must be highly reactive: player/NPC/mob actions have durable consequences.
- Late game supports extreme power expression (non-Euclidean magic, world artifacts, autonomous empires) with strict validation, counterplay, and performance budgets.

## 1.1) Reference Inspirations (Design Targets, Not Copy Targets)

Use the following titles as inspiration for quality bars and system feel only. Do not clone protected content, assets, or proprietary implementations.

- Nioh 3 (reference: high-skill action combat feel, encounter intensity, mastery progression cadence).
- Minecraft (reference: player creativity, block/build empowerment, crafting-driven agency).
- No Man's Sky (reference: large-scale exploration, discovery loops, systemic breadth).
- Ultimate Epic Battle Simulator 2 (reference: massive battle fantasy via scalable simulation abstraction).
- Sid Meier's Civilization (reference: strategic empire management, diplomacy, long-horizon political consequences).

All borrowed inspiration must be transformed into original mechanics and integrated with this project's custom systems.

## 2) Engine and Platform

- Use a custom engine architecture suitable for:
  - Deterministic authoritative simulation.
  - Tiered world simulation (near/far).
  - Massive persistent state.
  - Non-Euclidean/topological spatial features.
- Render pipeline must support:
  - Aggressive frustum and occlusion culling.
  - Distance-based LOD/HLOD and impostors.
  - Visibility-based non-render of hidden objects.
  - Debug/assist overlays (including marching-squares style visual helpers).

## 2.1) Temporary Art and Replacement Pipeline (Mandatory)

- All shipped art assets are considered temporary/proxy unless explicitly marked final.
- Every visual asset must be replaceable without gameplay code changes.
- Enforce data-driven asset references (IDs/registries), never hardcoded file paths in gameplay logic.
- Separate presentation from simulation:
  - Gameplay systems must depend on semantic tags/components, not specific meshes/materials/animations.
- Standardize placeholder contracts per asset type:
  - Character/NPC rigs, creature rigs, props, VFX, UI icons, environment kits.
- Require stable pivot/origin, scale conventions, socket naming, and animation state naming so final art can hot-swap.
- Maintain material/shader compatibility tiers:
  - Proxy material set -> production material set via mapping table.
- Use LOD/HLOD generation rules that can be regenerated when final art arrives.
- Build an asset validation step in CI for:
  - naming conventions
  - skeleton compatibility
  - collision and navmesh flags
  - missing replacement mappings
- Keep all placeholder art in clearly separated namespaces/folders and manifests to allow bulk replacement.
- Add "Art Swap Readiness" acceptance checks before major milestones.

## 3) Networking and Authority

- Server is authoritative for legality and canonical state.
- Client provides responsiveness via prediction/interpolation but does not author truth.
- Server must validate all impactful actions:
  - Combat contacts.
  - Spell/item legality.
  - Inventory/economy ownership.
  - Build/structure permissions.
  - Artifact transfer/use.
- Lag compensation and reconciliation are mandatory.

## 4) Replay and Dispute Record

- Every player interaction event must be recorded for replay-grade audit:
  - Contact points, actors, transforms, action IDs, outcomes, timestamps.
- Replay viewing can be user-toggled off, but server-side capture remains enabled.
- Logs must support anti-cheat investigation and moderation dispute resolution.

## 5) World Simulation Continuity

- No world freeze outside player proximity.
- Distant activities (e.g., shipments on remote planets) must continue.
- Use tiered simulation fidelity:
  - Hot (near players): high fidelity.
  - Warm: medium/event-driven.
  - Cold: aggregated deterministic background updates.
  - Archive: low-frequency strategic updates.
- Critical processes are durable jobs/state machines (never dropped silently).

## 6) Progression and Leveling

- Global level range: 1-9999.
- Required cap bands:
  - Humans: 120
  - Low monsters: 99
  - Mid monsters: 199
  - High monsters: 499
  - Demon lords: 999
  - Non-godkiller apex: 7500
  - Legendary creatures: 9999
- Fully built player to max should target ~200 hours (balance target, not guaranteed for all users).
- Gating model:
  - 100-level chunk unlocks via solo "mind dungeon" trials.
  - No friends/equipment in base rule set pre-1000.
  - Adaptive enemies learn and counter player style.
- Post-1000:
  - Soulbound equipment allowed.
  - Exclusive dungeon-only drops.
  - Every 10th trial: boss + massive swarms in huge arena with sparse cover.
  - Major breakpoint includes simultaneous self-echo encounters and shadow-self logic.
  - Enables non-Euclidean/spatial progression after successful milestones.

## 7) Evolution System

- Every creature type (players/NPCs/mobs) can evolve every 100 levels.
- Evolution yields hybrid race traits and expanded specialization options.
- Evolution grants increased magic/technical capacity and ability variety.
- System must use trait budgets and compatibility constraints to prevent runaway stacking.

## 8) Class Systems

- Battle classes: minimum 24 total.
  - 12 non-magic.
  - 12 magic.
- Technical classes: minimum 20 focused on automation, unit creation, infrastructure, devices, vehicles, and production.
- Players can combine up to 6 classes over progression with controlled loadout limits.
- Playstyle-driven/custom growth trees must emerge from actual behavior.

## 9) Magic System

- Magic runtime must be consistent, composable, and shared across:
  - Player spells.
  - NPC/mob abilities.
  - Automation effects.
  - Devices and rituals.
- Must support:
  - Teleport/spatial spells.
  - Intercept/counter spells.
  - Distance communication and spying/divination.
  - Niche utility spell families.
  - High-risk instant-death category with strict restrictions.
- 13-tier power model:
  - T1 approx candle scale.
  - T3 approx wok-stove scale.
  - T6 approx small meteor scale.
  - T8 approx continent-buster.
  - T10 cosmic kill-tier.
  - T12-13 legendary-entity use.
- Access constraints:
  - Humans up to T7 baseline.
  - Players up to T11 via costs.
  - T10 can be MP-only at max magic mastery.
  - T11-12 possible via specific world artifacts.

## 10) Construction and Building

- Building power is gated by Construction Magic progression.
- Construction Magic governs:
  - Complexity cap.
  - Manifest speed.
  - Stability.
  - Precision.
  - Enchantment and automation capacity.
- Lower-level deconstruction of higher-level builds is allowed only within limited gap windows (target: approx 5-level complexity gap).

## 11) Base Autonomy and Units

- Bases must run autonomously after task initiation:
  - Training.
  - Production.
  - Crafting/equipment upgrades.
  - Unit generation.
  - Defense operations.
- Users can command remotely.
- Unit caps can exceed 1,000,000 only via abstraction tiers:
  - Individual agents near relevance.
  - Squad/formation/strategic aggregate sim at distance.

## 12) Items and Artifacts

- Item system must include:
  - Classes/categories.
  - Tiers.
  - Levels.
  - Legendary and world-level items.
- World artifacts:
  - Total exactly 99.
  - One-of-a-kind globally (no duplicates active).
  - Tier groups I-III with distinct power/cost profiles.
- Additional exceptional "unmeasured" artifact may exist only under strict covenant-style safeguards.
- Non-magic users must have robust anti-magic itemized counters.

## 13) Economy, Crafting, and Logistics

- Crafting depth inspired by complex sandbox crafting ecosystems but not copied.
- Multi-step production chains, quality variables, and automation scripting required.
- Inventory model must support:
  - Personal inventory.
  - Base storage.
  - Regional/interplanetary logistics networks.
- Dungeons must provide unique resources and drops unavailable elsewhere.
- Dungeons must function as regional resource/economic hubs.

## 14) Civilization and World Structure

- Civilization scope:
  - 300+ civilizations.
  - 20 species minimum.
- Social cohesion varies by civilization/species branch.
- Not all civilizations advance similarly; many remain low-tech by systemic context.
- Only 20 spacefaring civilizations exist at macro tier.
- Geopolitics includes multi-alliance long-term conflict, broker profiteering, and uplift suppression.

## 15) Politics, Law, and Institutions

- Political simulation must include:
  - Diplomacy.
  - Trade treaties and route gating.
  - Espionage and counter-intel.
  - Crime/black markets.
  - Coercion/corruption/manipulation gradients by society.
- Must include institution separation:
  - Adventurer guilds.
  - Military structures.
  - Magic guilds.
- Contract systems accept diverse backgrounds if job quality conditions are met.

## 16) NPC/Mob Intelligence and Memory

- NPCs must:
  - Remember player actions and social events.
  - Learn from repeated work and improve skills.
  - Follow intrinsic goals (job, hobby, specialization).
  - Have level caps driven by education, skill, class, technical ability, and species factors.
- NPCs and mobs must be able to:
  - Innovate (new tech/magic).
  - Trade inventions with NPCs and players.
  - Diffuse useful innovations across routes and societies.

## 17) Dynamic Enemy Evolution

- High-tier enemies should:
  - Ignore players by default unless provoked/history exists.
  - Re-emerge stronger after defeat (chance-based rebirth).
  - Learn counters to prior kill methods.
  - Evolve AI and immunities/resistances with caps.
  - Mutate dungeons and summon followers autonomously.

## 18) Companion Creatures

- Include widely distributed cute elemental creatures.
- Elemental balance chart and spell-learning by type.
- Creatures can be captured, trained, assigned to combat/labor roles.
- Welfare/obedience systems required to prevent pure exploit loops.

## 19) Kingdom and Empire Management

- Players can direct:
  - Resource storage design and management policies.
  - City/kingdom growth.
  - Troop movement and war logistics.
  - Cost/income and treasury policy.
  - Spy activity and counter-intelligence.
- Factories/resource empires should convert into:
  - Political leverage.
  - Technical growth.
  - Power-balance disruption potential.
- Fortification, siege defense, and cross-civilization conflict must be supported according to evolution/legal stages.

## 20) Consequences and Permanence

- Small and large decisions must matter.
- Effects can decay selectively, but major actions must have durable world impact.
- World state must retain historical memory and cause-effect traceability.

## 21) Safety, Fairness, and Guardrails

- Any high-impact irreversible or extreme-power mechanic requires:
  - Multi-step eligibility.
  - Clear telegraphing.
  - Counterplay windows.
  - Auditable logs.
  - Optional mode/jurisdiction restrictions where necessary.
- Progression and social systems should model structural dynamics without hardcoding biological determinism.

## 22) Initial Engineering Milestones

1. Core simulation + net authority + replay pipeline.
2. Unified arcane/tech runtime + legality validator.
3. Construction Magic building + autonomous base jobs.
4. NPC memory/learning + economy/logistics.
5. Mind dungeon gates + adaptive enemy profiles.
6. Artifact registry + civilization diplomacy and faction pressures.
7. Endgame branches + non-Euclidean progression.

## 24) Live Content Authoring and AI-Assisted Generation

- The project must include a first-party content program/toolchain to create and update live content:
  - Dungeons
  - Mobs/creatures
  - Spells
  - Attacks/abilities
  - Unit behavior/attack patterns
  - Encounter scripts and reward tables
- Toolchain must support in-editor and live-service workflows with staged environments:
  - Local sandbox
  - Internal test shard
  - Staging shard
  - Production shard
- AI-assisted generation is supported, but all generated content is treated as untrusted until validated.

### 24.1) Content Pipeline Stages

1. Generate/author content (manual or AI-assisted).
2. Static validation:
   - schema correctness
   - dependency integrity
   - budget compliance (performance, spawn counts, effect complexity)
   - legality/security rules
3. Simulation validation:
   - deterministic execution checks
   - anti-exploit checks
   - server cost bounds
4. Playtest gate:
   - automated encounter tests
   - scripted QA scenarios
   - optional human review sessions
5. Approval workflow:
   - designer approval
   - engineering/runtime approval
   - balance approval
6. Controlled rollout:
   - canary release
   - telemetry monitoring
   - rollback support
7. Promotion to base game content only after passing all required gates.

### 24.2) Safety and Governance Requirements

- No direct AI-generated content deployment to production.
- All live-added content must be versioned, signed, and reversible.
- Runtime kill-switches must exist for problematic live content.
- Add audit trails:
  - who generated/edited/approved
  - what changed
  - when promoted/rolled back
- Generated content must be reviewable in a human-readable diff format.

### 24.3) Runtime Constraints for Live Additions

- Hot-added content must obey the same authority and legality checks as shipped content.
- New attacks/spells/patterns must compile through the same runtime validators.
- Dungeon/mob additions must not exceed per-zone budget limits.
- If budget overruns are detected in production telemetry, automatic degradation/disable policies apply.

## 23) Acceptance Criteria (Project-Level)

- Server remains authoritative and scalable under mixed near/far world load.
- Distant world jobs continue while local combat occurs.
- Replay evidence can reconstruct contact outcomes reliably.
- Core gameplay loop (combat + building + crafting + politics) is fun at low, mid, and high power.
- World reacts persistently to player/NPC actions and remains coherent over long sessions.
- Temporary/proxy art can be swapped with production art by content pipeline updates, with no required gameplay code rewrites.
- Live-authored (including AI-assisted) dungeons/mobs/spells/behaviors can be created, validated, playtested, and safely promoted to base game content with rollback capability.

## 25) Autonomous Bot Framework (Testing, Validation, and Assisted Implementation)

- The project must include an autonomous bot ecosystem with clearly separated responsibilities:
  - World Exploration QA Bot
  - Route/Clearability Evaluation Bot
  - Validation/Compliance Bot
  - Assisted Feature Implementation Bot (guarded)
- Bots must run continuously in CI and on scheduled world sweeps for staging shards.

### 25.1) World Exploration QA Bot

- Traverses world content repeatedly as features are added.
- Attempts broad path coverage:
  - quests
  - dungeons
  - travel routes
  - logistics routes
  - combat encounters
  - progression gates
- Reports:
  - crashes and soft-locks
  - nav/pathing failures
  - missing triggers/events
  - unreachable objectives/rewards
  - severe performance spikes and memory leaks

### 25.2) Route/Clearability and Fun-Heuristic Bot

- Systematically tries alternate routes and solution styles.
- Detects "not clearable" or "unclear progression" states.
- Computes quality metrics:
  - clearability rate
  - time-to-clear variance
  - dead-end frequency
  - confusion score (objective ambiguity heuristics)
  - frustration markers (excessive retries/fails)
- Flags routes/encounters that are likely unfun or unfair for human review.
- Final fun decisions remain human-approved; bot provides decision support evidence.

### 25.3) Validation/Compliance Bot

- Verifies every build/content package against:
  - schema and dependency rules
  - gameplay legality checks
  - anti-cheat and authority contracts
  - performance budgets
  - replay event completeness
  - asset swap/readiness constraints
- Blocks promotion when hard requirements fail.

### 25.4) Assisted Feature Implementation Bot (Guarded)

- Can propose or implement scoped features/fixes in a controlled branch/workspace.
- All bot-authored changes require:
  - static analysis and test pass
  - validation bot approval
  - human code/design review
  - staged playtest before merge
- Bot may not directly deploy to production.
- Bot must include change rationale and risk notes for every submission.

### 25.5) Orchestration and Safety

- Use a central Bot Orchestrator service to:
  - assign tasks
  - track run status
  - aggregate findings
  - prioritize regressions
  - open actionable reports/issues
- Require deterministic seed replay for any reported failure where possible.
- Support automatic bisection to identify regression-introducing changes.
- Provide severity-based paging for critical blockers.

### 25.6) Acceptance for Bot System

- New features trigger automated bot sweeps before promotion.
- Critical path regressions are detected and reported with reproducible artifacts.
- Validation bot reliably prevents non-compliant builds from release.
- Assisted feature bot improves throughput while preserving human approval control.

## 26) Cohesion Requirement: One Unified Structure

- All major systems must interoperate through shared core models, not isolated minigames.
- Combat, crafting, building, logistics, diplomacy, AI society, and progression must exchange state through a unified simulation contract.
- A single canonical world state ledger is required for:
  - gameplay events
  - economic transactions
  - political shifts
  - ownership and legality
  - replay/audit traces
- No feature may ship as standalone if it bypasses authority, progression, economy, or consequence models.

### 26.1) Cross-System Coupling Rules

- Combat outcomes must influence economy and politics where relevant.
- Logistics disruptions must affect military readiness and city output.
- Building/factory growth must affect diplomacy and threat perception.
- Social policy and governance choices must influence magic stability and progression gates where defined.
- NPC innovation and faction behavior must feed directly into market and conflict systems.

### 26.2) Unified Data and Runtime Contracts

- Shared IDs and schemas for actors, factions, items, regions, and jobs.
- Shared legality validation path for player actions, AI actions, and live-authored content.
- Shared budget framework (CPU/memory/sim cost) across combat, AI, world jobs, and live content.
- Shared telemetry and replay instrumentation across all subsystems.

### 26.3) Cohesion Acceptance Criteria

- End-to-end scenario tests must demonstrate that a change in one pillar propagates correctly to others.
- Feature additions failing integration contracts are blocked until unified behavior is restored.
- User experience must remain coherent: no contradictory rules between first-person gameplay and strategy/world layers.

## 27) System Interaction Matrix (Engineering Contract)

The project must maintain a living interaction matrix mapping every major subsystem to its read/write effects on shared world state.

### 27.1) Matrix Requirements

- For each subsystem, document:
  - Inputs (what state it reads).
  - Outputs (what state it writes).
  - Update cadence (real-time, tick, batched, event-driven).
  - Authority source (client, server, tooling, approved live content).
  - Validation path and failure behavior.
- Matrix must be versioned and updated with every feature PR that changes cross-system behavior.
- CI must check matrix coverage against subsystem manifests and fail if undocumented interactions are introduced.

### 27.2) Minimum Subsystems to Track

- Combat and ability runtime.
- Building and construction magic.
- Crafting/industry/factory pipelines.
- Inventory/storage/logistics.
- NPC/mob AI and learning.
- Factions/civilizations/diplomacy.
- Economy/markets/trade routes.
- Progression/level gates/evolution.
- Artifacts and world-unique items.
- Replay/telemetry/moderation.
- Live content pipeline and bot systems.

### 27.3) Integration Scenarios (Must Exist in Test Suite)

- Military conflict interrupts logistics, and shortages alter combat readiness and political stability.
- Dungeon control shifts regional economy, faction pressure, and guild contract demand.
- Social policy changes alter NPC behavior, migration, diplomacy, and high-tier magic stability gates.
- New live-authored spell/device impacts combat, economy, and legality validators without bypassing authority.

## 28) Human Feedback and Product Adaptation Loop

Human critique must be a first-class product input alongside telemetry and automated bots.

### 28.1) Feedback Collection Channels

- In-game structured feedback forms (context-aware).
- Session-end surveys for fun, clarity, fairness, and thematic fit.
- Bug/friction quick-report tools with replay/event attachment.
- Moderated playtest panels and creator councils.

### 28.2) Required Feedback Schema

Each feedback item must capture:
- Category:
  - Not fun
  - Not working (bug/balance/clarity)
  - Not fitting theme
  - Accessibility/performance concern
- Player intent (what they tried to do).
- Observed result vs expected result.
- "Why" rationale in player words.
- Severity and frequency estimates.
- Optional linked evidence:
  - replay clip
  - event IDs
  - location/build/version metadata.

### 28.3) Triage and Prioritization

- Create a Feedback Triage Service that combines:
  - human reports
  - telemetry
  - bot findings
  - regression data
- Prioritize with weighted scoring:
  - player impact
  - recurrence rate
  - thematic damage
  - progression blockage
  - exploit/security risk
- Generate an actionable change queue with clear owner, scope, and ETA.

### 28.4) Critique-to-Change Workflow

1. Intake and de-duplication.
2. Reproduction using replay and seeds.
3. Root-cause classification (design, balance, UX, code defect, content issue).
4. Proposed fix reviewed by design + engineering.
5. Validate in bot sweeps + targeted human playtest.
6. Staged rollout with telemetry guardrails.
7. Post-change verification:
   - issue recurrence drops
   - fun/clarity/thematic fit scores improve
   - no critical regressions introduced.

### 28.5) Governance and Transparency

- Maintain a public/internal changelog linking major fixes to feedback themes.
- Keep a "Known Issues / Intentional Friction" board to separate bugs from deliberate design.
- Add periodic review rituals (e.g., weekly triage, milestone retrospectives) with explicit accept/reject rationale for major feedback clusters.

### 28.6) Acceptance Criteria for Feedback Loop

- High-severity feedback receives reproducible investigation artifacts.
- Repeated "not fun" and "not fitting theme" clusters trigger design review, not only bug fixes.
- Product changes demonstrably incorporate validated critique and improve targeted experience metrics.
