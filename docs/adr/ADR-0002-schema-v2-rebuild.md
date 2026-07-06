# ADR-0002: One Coherent Schema v2 Rebuild

Status: Accepted
Date: 2026-07-06

## Context

The current model (`ShootPlan` with cascade `[ShootPlanItem]`) has no persisted stage: stages are computed by grouping items on `(stageOrderIndex, stageTitle)` (`Arc/Features/Planning/Domain/ShootPlan.swift:104`). This already loses data — the stage `goal` is editable in the import UI but dropped at commit because `ShootPlanItem` has no field for it (`ImportPlanFlowView.swift:327-350`) — gives stages no stable identity for geofencing or telemetry, and re-groups on hot paths in field mode. The app is pre-ship with dev/personal data only, so one coherent rebuild is cheaper and safer than three incremental migrations toward the same shape.

## Decision

Rebuild persistence as schema v2 in P2 as a single change, replacing the `Shoot*` types outright (deliberate naming break; do not alias or bridge old names):

| Entity | Notes |
|---|---|
| `Trip` | Root aggregate; owns artifacts and days. |
| `TripArtifact` | kinds: `ideas` \| `shootList` \| `script`. The 3-artifact owner workflow, persisted. |
| `ShootDay` | One field day within a trip. |
| `Stop` | A place; preserves `sourceGeoAnchor` verbatim from import. |
| `Stage` | **Persisted entity** with identity, order, `goal`, kind: `standard` \| `beforeLeaving` \| `safetyNet`. Replaces computed grouping. |
| `CaptureItem` | origin: `planned` \| `safetyNet` \| `fieldAdded`. |

Rules: define the full entity/field contract in [../05-data-model.md](../05-data-model.md) before writing code; do not implement schema v2 before `ArcPlanDocument` exists ([ADR-0004](ADR-0004-arcguide-document-interchange.md)); do not write migration code from the old store ([ADR-0003](ADR-0003-store-reset-pre-ship.md)); derive "story is safe" from persisted `Stage`/`CaptureItem` state, never from recomputed grouping.

## Consequences

**Positive:**
- `Stage.goal` and stage identity are first-class: fixes the goal-drop defect structurally and unblocks geofenced stop surfacing ([ADR-0007](ADR-0007-while-in-use-location-surfacing.md)), stage-level telemetry, and the stage mantra in field mode.
- `CaptureItem.origin` makes Story Safety Net dedup trivial (fixes the class of bug in `FieldView.swift:533-568`).
- `TripArtifact` makes the ideas → shoot list → script loop a data-model fact, enabling script generation from execution data.
- No grouping on field-mode hot paths; battery-light requirement gets structural help.

**Negative:**
- Every feature surface (Field, Shoots, Planning, Review, Locations) must be ported in one phase; P2 is a big-bang change with no incremental shipping inside it.
- The naming break invalidates existing code pointers and muscle memory; all docs cite v2 names only.
- Existing on-device data is abandoned (accepted via [ADR-0003](ADR-0003-store-reset-pre-ship.md)).

**Follow-ups:**
- P2: write the full schema contract in [../05-data-model.md](../05-data-model.md) first, then implement.
- P2: delete `ShootPlan` / `ShootPlanItem` / `ShootLocation` in the same change; no compatibility layer.
- P2: map `ArcPlanDocument` ↔ schema v2 in `Arc/Features` (mapping code lives outside `Arc/Core/Documents`).

## Links

- [../05-data-model.md](../05-data-model.md) — owner doc for the v2 contract
- [ADR-0003-store-reset-pre-ship.md](ADR-0003-store-reset-pre-ship.md) — why no migration
- [ADR-0004-arcguide-document-interchange.md](ADR-0004-arcguide-document-interchange.md) — document format precedes storage
- [../08-roadmap.md](../08-roadmap.md) — P2 scope
