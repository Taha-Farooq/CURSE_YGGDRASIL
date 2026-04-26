# CURSE One-Person Team Execution Loop

This playbook defines how to run product, design, engineering, QA, and live-ops as a single operator.

## Daily Loop

1. **Review Inputs**
   - New feedback items (`FEEDBACK_SCHEMA.json` format).
   - Bot findings (world explorer, route clearability, validation bot).
   - Telemetry regressions and crash trends.

2. **Triage**
   - Score each issue by:
     - player impact
     - recurrence
     - thematic damage
     - exploit risk
   - Select top priorities for the day.

3. **Plan and Change**
   - Update requirements/spec if behavior contract changes.
   - Implement in smallest possible slices.
   - Keep temporary art and data-driven references intact.

4. **Validate**
   - Run static checks.
   - Run deterministic scenario tests.
   - Run bot sweeps for route clearability and progression integrity.

5. **Playtest**
   - Perform focused human pass:
     - Is it fun?
     - Is it clear?
     - Does it fit theme?

6. **Promote**
   - Sandbox -> internal test -> staging.
   - Monitor telemetry.
   - Roll back immediately if critical regressions appear.

7. **Document**
   - Update interaction matrix.
   - Link changes to feedback IDs.
   - Record what improved and what still fails.

## Weekly Loop

- Review top feedback clusters.
- Review "not fun" and "not fitting theme" separately from pure bug counts.
- Rebalance roadmap around highest user impact.
- Verify every new feature has:
  - replay visibility
  - authority compliance
  - cross-system matrix coverage

## Definition of Done (Per Feature)

- Requirement/spec updated.
- Interaction matrix updated.
- Tests added/updated.
- Bot validation passed.
- Human playtest completed.
- Feedback recurrence decreased after release.

