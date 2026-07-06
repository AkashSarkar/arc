# ADR-0003: SwiftData Store Reset at Schema v2 (Pre-Ship Only)

Status: Accepted
Date: 2026-07-06

## Context

Schema v2 ([ADR-0002](ADR-0002-schema-v2-rebuild.md)) replaces every persisted type with new entities and new names. The app has never shipped externally — the only data in any store is the owner's dev/dogfood data. Writing a `SchemaMigrationPlan` from `ShootPlan`/`ShootPlanItem`/`ShootLocation` to `Trip`/`Stage`/`CaptureItem` would be the most complex code in the app, exercised exactly once, protecting data one person can regenerate by re-importing a markdown plan.

## Decision

When schema v2 lands, reset the SwiftData store. Write ZERO migration code.

- Detect the old store on launch, delete it (or point the `ModelContainer` at a new store URL), and start clean.
- Optional, best-effort, one-shot courtesy: before deletion, export existing plans to `ArcPlanDocument` JSON files ([ADR-0004](ADR-0004-arcguide-document-interchange.md)) in the app's Documents directory so the owner can re-import anything worth keeping. If this export fails, proceed with the reset anyway — it must not block.
- Do not build UI for this beyond a single informational notice.

**Expiry — read before relying on this ADR:** this decision is valid ONLY while no external build exists. It is superseded the day an external TestFlight build ships. From that day forward, every schema change MUST ship a `SchemaMigrationPlan` (or versioned lightweight migration), with no exceptions. Flip this ADR's Status to `Superseded` (per the rule in [ADR-0000](ADR-0000-template.md)) referencing the ADR or roadmap entry that records the TestFlight milestone.

## Consequences

**Positive:**
- P2 spends its complexity budget on the v2 model and feature ports, not on throwaway migration code.
- No risk of half-migrated hybrid states; the v2 store is clean by construction.
- The courtesy export doubles as the first real exercise of `ArcPlanDocument` serialization.

**Negative:**
- The owner's existing dogfood plans and field-execution history are lost unless re-imported from the exported JSON; execution telemetry (capture/skip timestamps) is lost entirely.
- Sets a precedent that is only safe pre-ship — hence the hard expiry above. An agent applying this pattern after external distribution would be violating this ADR, not following it.

**Follow-ups:**
- P2: implement old-store detection + reset + courtesy export in `Arc/App` startup.
- P2 exit criteria: confirm reset behavior on a device that had the old store ([../09-quality.md](../09-quality.md)).
- G-gated: when the first external TestFlight build is cut, write the superseding ADR mandating `SchemaMigrationPlan` and flip this Status.

## Links

- [ADR-0002-schema-v2-rebuild.md](ADR-0002-schema-v2-rebuild.md) — the schema change this reset serves
- [ADR-0004-arcguide-document-interchange.md](ADR-0004-arcguide-document-interchange.md) — export target for the courtesy dump
- [../05-data-model.md](../05-data-model.md) — schema v2 contract
- [../08-roadmap.md](../08-roadmap.md) — P2 placement and gates
