# Legacy Doc Triage (2022-2025)

Source: old Yggdrasil build doc provided in chat.  
Goal: keep what still fits current architecture, drop what conflicts, and turn useful parts into executable direction.

## 1) Keep and Merge (High Value)

These align strongly with current `REQUIREMENTS.md` and should be retained:

- Hypercomplex hybrid core: action RPG + systems sim + strategy layer.
- Magic + engineering dual track with cross-domain solutions.
- Custom spellcasting and multi-spellcasting.
- Deep item taxonomy with world-tier artifacts.
- Fully destructible environments (kept with performance/authority constraints).
- Dungeon variety (floor, trap, tomb, adventure).
- NPC civilization growth, conflict, and economy loops.
- Large-scale command/army gameplay.
- Horizontal MMO/post-campaign progression concept.
- Sentient/AGI-risk ideas (kept under strict safety gates).
- Rich philosophical/lore framing as tone material.

## 2) Keep but Reframe (Needs Modernization)

These ideas are useful but need stricter implementation framing:

- "Serverless/small scale teamplay" -> keep as optional networking mode, but preserve authoritative validation for shared state.
- "Isekai 1-4" campaign framing -> keep as narrative progression arcs, map to modern chapter/epoch structure.
- Extreme power scaling tables -> keep fantasy intent, map to current 1-9999 unified cap model.
- Drug/cooking/effects sections -> treat as mature-content optional modules with legal/safety gating.
- Personality descriptors including prejudiced behavior -> keep as structural social simulation, avoid deterministic/species-essentialist modeling.

## 3) Drop / Archive (Conflicts or Low ROI now)

- Redundant duplicate headings and repeated table blocks.
- Meme placeholders/temporary terms ("yeetus", "nitpicky shit") in production specs.
- Unbounded physics detail without budget framing.
- Any mechanic that bypasses validation, replay, anti-cheat, or authority contracts.

## 4) Direct Mapping to Current Program

- Demon Lord / apex entities -> now covered in `REQUIREMENTS.md` sections 29 and 30.
- Advanced NPC creator with power/temperament -> covered in section 30.
- Goal alignment automation -> covered in section 31 + `goal-alignment-bot`.
- Test discovery + bot generation -> covered by `test-research-bot` and `bot-maker-bot`.

## 5) Immediate Backlog Inserts (from legacy that still matter)

Create/retain tasks for:

1. Environmental destruction budget model (authoritative + scalable).
2. Dungeon taxonomy and procedural constraints (floor/trap/tomb/adventure).
3. Magic-language and spell-structure grammar v1.
4. Engineering progression ladder (mechanical -> digital -> hybrid arcane compute).
5. Player/NPC dual growth parity rules (skills, classes, custom abilities).
6. Campaign arc structure ("Isekai-style" transitions) mapped to current progression gates.

## 6) Writing/Spec Style Normalization Rules

- Keep creative flavor in lore docs, not in runtime contract docs.
- Use explicit acceptance criteria for every system section.
- Every new subsystem must define:
  - authority boundary
  - replay/telemetry events
  - budget constraints
  - failure modes

## 7) Final Decision

This legacy doc is valuable as a *vision archive* and *idea reservoir*.  
It should not be used as a direct build spec without normalization.

Use it as:
- creative source for lore/tone/mechanics exploration,
- but enforce modern constraints from `REQUIREMENTS.md` for implementation.

