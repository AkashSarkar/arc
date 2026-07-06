# ADR-0007: While-In-Use Location Surfacing (Scoped AGENTS.md Amendment)

Status: Accepted
Date: 2026-07-06

## Context

`AGENTS.md:22` bans background execution and location use without an explicit product requirement — a correct default for a battery-critical field app. Field-behavior truth: the owner does not scroll checklists mid-shoot; they glance at checkpoints. Surfacing the right Stop and its stage mantra at the right moment (arriving at a stop, golden hour approaching) is core to glanceable field mode, and requires a scoped location capability. This ADR is the explicit product requirement AGENTS.md demands.

## Decision

Geofenced stop surfacing, Live Activities, and golden-hour nudges ARE an explicit product requirement (P3, [../07-field-ux.md](../07-field-ux.md)). This ADR amends the `AGENTS.md:22` ban for exactly this scope and nothing more.

Hard scope — every clause is binding:

| Boundary | Rule |
|---|---|
| Authorization | `.authorizedWhenInUse` ONLY. Never request Always authorization. Never add background-location capability to the app target. |
| Surfacing mechanism | Live Activities (Lock Screen / Dynamic Island) over persistent background location. Region monitoring may wake the app briefly per platform behavior; Arc must not run continuous background location updates. |
| Data handling | NO location logging, NO location analytics, NO location persisted beyond what a `Stop`/`CaptureItem` already stores from the plan and explicit capture actions. Raw CLLocation streams are consumed and dropped. |
| Permission denied | Graceful, full-featured fallback: field mode works completely with manual stage advancement. No nag loops; one contextual explanation, then respect the answer. |
| Battery | Battery-light is an ACCEPTANCE CRITERION, not an aspiration: a full field day with surfacing enabled must not make Arc a noticeable battery line item. Verification method and threshold live in [../09-quality.md](../09-quality.md). |

Golden-hour nudges compute from `SunMoonCalculator` (already in `Arc/Services/Enrichment`) against planned Stop coordinates — they need scheduling, not tracking.

Any expansion of this scope (Always authorization, background updates, location analytics) requires a new ADR superseding this one; agents must not widen it incrementally.

## Consequences

**Positive:**
- Field mode gets its glanceability payoff: the right stage mantra surfaces without the owner opening the app, matching how creators actually work mid-shoot.
- The AGENTS.md ban stays intact for everything outside this scope; the amendment is auditable and narrow.
- While-in-use + Live Activities keeps the privacy story clean for App Review and for the eventual "field-verified guide" trust narrative.

**Negative:**
- While-in-use-only means surfacing degrades when the app has been terminated and no Live Activity is running; some arrivals will be missed. Accepted — correctness of the ban's spirit beats coverage.
- Geofencing precision in dense urban stops (multipath GPS) will produce late or missed triggers; manual advancement remains the primary path, surfacing is assistive.
- Battery acceptance testing adds a real-device, full-day test burden to P3 exit criteria.

**Follow-ups:**
- P3: implement region monitoring + Live Activity per [../07-field-ux.md](../07-field-ux.md); requires persisted `Stage`/`Stop` identity from schema v2 ([ADR-0002](ADR-0002-schema-v2-rebuild.md)).
- P3: add the permission-denied UX path and battery acceptance test to [../09-quality.md](../09-quality.md).
- Now: record the pointer to this ADR next to the rule at `AGENTS.md:22` (conduct file remains the authority on conduct).

## Links

- [../07-field-ux.md](../07-field-ux.md) — owner doc for field-mode behavior
- [../09-quality.md](../09-quality.md) — battery acceptance criterion
- [ADR-0002-schema-v2-rebuild.md](ADR-0002-schema-v2-rebuild.md) — stage/stop identity prerequisite
- /AGENTS.md — the amended conduct rule (AGENTS.md:22)
