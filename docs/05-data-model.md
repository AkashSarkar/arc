# 05 — Data Model

> **Agent Brief** — Status: Current | Applies to: owner-test MVP schema v2 and document interchange | Owner doc for: persistence schema, entity specifications, old→new mapping, store reset strategy, ArcPlanDocument/ArcGuideDocument interchange format.
> Read [docs/00-index.md](00-index.md) first. Behavioral rules: /AGENTS.md (wins on conduct). Current build phase: see [docs/08-roadmap.md](08-roadmap.md).
> Code pointers verified against `task-owner-mvp-through-p4` after schema-v2 implementation (2026-07-07). Re-verify line numbers before editing.

Related: [docs/04-architecture.md](04-architecture.md) (layering rules), [docs/06-import-spec.md](06-import-spec.md) (what produces documents), [docs/07-field-ux.md](07-field-ux.md) (what consumes stages), [docs/adr/ADR-0002-schema-v2-rebuild.md](adr/ADR-0002-schema-v2-rebuild.md), [docs/adr/ADR-0003-store-reset-pre-ship.md](adr/ADR-0003-store-reset-pre-ship.md), [docs/adr/ADR-0004-arcguide-document-interchange.md](adr/ADR-0004-arcguide-document-interchange.md).

---

## 0. Current implementation snapshot

Schema v2 is now the app's active SwiftData model on the owner-test MVP branch:

- Active models live in [Arc/Features/Trips/Domain/TripModels.swift](../Arc/Features/Trips/Domain/TripModels.swift): `Trip`, `TripArtifact`, `ShootDay`, `Stop`, `Stage`, and `CaptureItem`.
- The app model container is wired to those schema-v2 entities in [Arc/App/ArcApp.swift](../Arc/App/ArcApp.swift).
- Import and `.arcguide` documents map through [Arc/Features/Trips/Domain/TripDocumentMapper.swift](../Arc/Features/Trips/Domain/TripDocumentMapper.swift).
- The retired v1 root types `ShootLocation`, `ShootPlan`, `ShootPlanItem`, and `PlanViewModel` are deleted.
- Coordinates are optional on `Stop`; unresolved imported stops keep `sourceGeoAnchor` and render as needing location instead of fabricating `0,0`.
- Imported-plan commit does not require a fallback picked location; location picking remains only in the manual single-stop "New Location Plan" flow.
- Completed trips generate a `TripArtifact(kind: script)` and can export a structured `ArcGuideDocument`.

The v1 notes below are historical context for old→new mapping only.

## 1. Retired model (schema v1, historical)

The previous build used three `@Model` classes plus value-type draft structs. All plans were reachable only through their `ShootLocation`; there was no trip-level container. These files no longer exist on the owner-test MVP branch.

### 1.1 `ShootPlan` — [Arc/Features/Planning/Domain/ShootPlan.swift:4](../Arc/Features/Planning/Domain/ShootPlan.swift)

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | `@Attribute(.unique)` |
| `createdAt` | `Date` | |
| `notes` | `String` | |
| `rawResponse` | `String` | raw AI/import text |
| `sourceRawValue` | `String?` | `CapturePlanSource`: `locationGenerated` \| `importedText` |
| `importedPlanText` | `String` | default `""` |
| `storySummary` | `String` | default `""` |
| `currentStageOrderIndex` | `Int` | default `0`; field-mode cursor |
| `outputIntentRawValue` | `String` | |
| `captureMediumRawValue` | `String?` | |
| `targetPlatformRawValue` | `String?` | |
| `stylePresetRawValue` | `String?` | |
| `shootWindowModeRawValue` | `String` | |
| `shootWindowSummary` | `String` | |
| `shootDate` / `shootStartTime` / `shootEndTime` | `Date` | non-optional, defaulted to `Date()` |
| `isApprovedForField` | `Bool` | |
| `approvedAt` / `completedAt` | `Date?` | |
| `location` | `ShootLocation?` | inverse of `ShootLocation.plan` |
| `items` | `[ShootPlanItem]` | `@Relationship(deleteRule: .cascade)` |

Computed (selected): `fieldStages` (ShootPlan.swift:104 — see §1.5), `currentStage` (:123), `capturedCount`/`skippedCount`/`resolvedCount`/`missingCount` (:136-150), `completionProgress`/`fieldCompletionProgress` (:152-160).

### 1.2 `ShootPlanItem` — [Arc/Features/Planning/Domain/ShootPlan.swift:163](../Arc/Features/Planning/Domain/ShootPlan.swift)

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | `@Attribute(.unique)` |
| `orderIndex` | `Int` | global across the whole plan, not per stage |
| `title` | `String` | |
| `role` | `String` | free text; import writes `item.kind.title` into it (ImportPlanFlowView.swift:531) — redundant with `kind` |
| `guidance` | `String` | |
| `isCaptured` | `Bool` | |
| `stageTitle` | `String` | default `"Shot List"` — denormalized stage identity |
| `stageOrderIndex` | `Int` | default `0` — denormalized stage identity |
| `stageGoal` | `String` | default `""` — transitional P0 denormalized stage goal (deleted in v2 when `Stage.goal` lands) |
| `kindRawValue` | `String?` | `FieldGuideItemKind`: `shot` \| `voice` \| `sound` \| `transition` \| `note` |
| `priorityRawValue` | `String?` | `FieldGuidePriority`: `must` \| `optional` |
| `isBeforeLeaving` | `Bool` | default `false` |
| `isSkipped` | `Bool` | default `false` |
| `fieldNote` | `String` | default `""` |
| `capturedPhotoData` | `Data?` | `@Attribute(.externalStorage)` |
| `capturedPhotoAttachedAt` | `Date?` | |
| `plan` | `ShootPlan?` | inverse of `ShootPlan.items` |

Computed: `kind`, `priority`, `displayRoleTitle`, `isResolved` (`isCaptured || isSkipped`), `resolvedStageTitle`, `resolvedStageOrderIndex`, `resolvedStageGoal` (ShootPlan.swift:221-253).

### 1.3 `ShootLocation` — [Arc/Features/Locations/Domain/ShootLocation.swift:10](../Arc/Features/Locations/Domain/ShootLocation.swift)

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | `@Attribute(.unique)` |
| `name` | `String` | |
| `latitude` / `longitude` | `Double` | **non-optional** — import now requires a picked location and commits its coordinates (ImportPlanFlowView.swift:495-499); optionality arrives with `Stop` in v2 |
| `createdAt` | `Date` | |
| `enrichmentJSON` | `String` | cached Overpass/Wikipedia/weather payload |
| `lastEnrichedAt` | `Date?` | |
| `plan` | `ShootPlan?` | `@Relationship(deleteRule: .cascade, inverse: \ShootPlan.location)` — one plan per location |

Computed: `status` (`draft` \| `active` \| `completed`, derived from `plan`).

### 1.4 FieldGuide draft value types — [Arc/Features/Planning/Domain/FieldGuide.swift](../Arc/Features/Planning/Domain/FieldGuide.swift) (uncommitted)

Not persisted. The import editor ([ImportPlanFlowView.swift](../Arc/Features/Shoots/Presentation/ImportPlanFlowView.swift)) binds to these; commit flattens them into `ShootPlanItem` rows.

| Type | Fields | Notes |
|---|---|---|
| `FieldGuideDraft` (FieldGuide.swift:75) | `title`, `storySummary`, `stages: [FieldGuideStageDraft]` | `Equatable`; `.empty` static |
| `FieldGuideStageDraft` (:87) | `id UUID`, `title`, `goal`, `sourceGeoAnchor`, `items: [FieldGuideItemDraft]` | **has `goal`** — persisted via the transitional `stageGoal` stopgap (§1.5) |
| `FieldGuideItemDraft` (:109) | `id UUID`, `title`, `guidance`, `kind`, `priority`, `isBeforeLeaving`, `sourceLine`, `isSynthetic` | |
| `FieldGuideStageKey` (:140) | `orderIndex Int`, `title String` | `Hashable` grouping key |
| `FieldGuideStage` (:145) | `orderIndex`, `title`, `goal`, `items: [ShootPlanItem]` | read-only projection; `progress`, `missingItems`, counts |
| Enums (:3-73) | `CapturePlanSource`, `FieldGuideItemKind`, `FieldGuidePriority` | raw-value `String` enums — the convention v2 keeps |

### 1.5 The three structural problems

1. **Stage goal has no stage-level home.** The P0 stopgap persists `FieldGuideStageDraft.goal` by denormalizing it per item into the transitional `stageGoal` field (written in the commit loop at ImportPlanFlowView.swift:522-545; read back into `FieldGuideStage.goal` by `fieldStages`). The residual issue: the goal is copied onto every item rather than stored as a stage-level property, so the stage mantra ([docs/07-field-ux.md](07-field-ux.md)) still lacks proper storage until `Stage.goal` in v2.
2. **Stage identity is a fragile string pair.** A "stage" exists only as matching `(stageOrderIndex, stageTitle)` values denormalized onto every item. Renaming a stage means rewriting N items; a typo in one item forks the stage; there is no place for stage-level state (goal, kind, safety-net targeting).
3. **`fieldStages` is computed on every access.** ShootPlan.swift:104 rebuilds a `Dictionary(grouping:)` + two sorts each time it is read. `FieldView` and progress rings read it in hot UI paths, so every SwiftData change re-runs the grouping for the whole plan.

These are design consequences of v1. P0 patches the two user-visible data problems so dogfooding is truthful; schema v2 fixes the model shape structurally (ADR-0002).

---

## 2. Decisions (summary)

| # | Decision | Rationale | ADR |
|---|---|---|---|
| D1 | `Stage` becomes a **persisted entity** in schema v2 | Fixes all three §1.5 problems at the root: real identity, real `goal` column, no per-access grouping | [ADR-0002](adr/ADR-0002-schema-v2-rebuild.md) |
| D2 | `Trip` umbrella lands **now, in the same rebuild** | Owner's real unit of work is a multi-day trip with 3 artifacts; retrofitting Trip later would force a second migration | ADR-0002 |
| D3 | **One coherent rebuild**, not incremental entity additions | Each incremental entity would need its own store reset/migration; one rebuild = one reset | ADR-0002 |
| D4 | **Store reset instead of SwiftData migration** — pre-ship only | Only dev data exists; migration code would be pure waste. Expires the day an external TestFlight build ships | [ADR-0003](adr/ADR-0003-store-reset-pre-ship.md) |
| D5 | Interchange document (`ArcPlanDocument`/`ArcGuideDocument`) is defined **before** storage v2 | The document is the contract; storage is an implementation. P1 parser targets the document; P2 storage matches it | [ADR-0004](adr/ADR-0004-arcguide-document-interchange.md) |

**P0 stopgaps (delete or supersede in P2):**

- Add a transitional `stageGoal: String` field to `ShootPlanItem`, denormalized exactly like `stageTitle`, so the import editor's goal is no longer dropped. `fieldStages` grouping reads it into `FieldGuideStage`. This is explicitly throwaway — it dies with `ShootPlanItem` in the v2 rebuild.
- Require the imported-plan flow to pick a real `ShootLocation` before commit instead of writing placeholder `0,0` coordinates. This keeps v1 location-scoped features truthful until P2 replaces `ShootLocation`-as-root with `Trip` / `Stop` and optional stop coordinates.

---

## 3. Schema v2 entity specifications

All entities live in `Arc/Features/Trips/Domain/` and are implemented. Follow existing conventions: `@Model` classes, `@Attribute(.unique) var id: UUID`, raw-value `String` enum storage (`xxxRawValue: String` + computed typed accessor with a safe default), cascade delete downward, optional inverse pointer upward. Hierarchy:

```
Trip ─┬─ cascade → [TripArtifact]
      └─ cascade → [ShootDay] ── cascade → [Stop] ── cascade → [Stage] ── cascade → [CaptureItem]
```

### 3.1 `Trip`

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | `@Attribute(.unique)` |
| `createdAt` | `Date` | |
| `title` | `String` | e.g. "Kyoto, 4 days" |
| `summary` | `String` | the story in one paragraph; feeds script generation |
| `statusRawValue` | `String` | `planning` \| `active` \| `completed` \| `archived` |
| `outputIntentRawValue` | `String` | reuse existing `OutputIntent` enum |
| `captureMediumRawValue` | `String` | reuse existing `CaptureMedium` |
| `targetPlatformRawValue` | `String` | reuse existing `TargetPlatform` |
| `stylePresetRawValue` | `String` | reuse existing `CaptureStylePreset` |
| `startDate` | `Date?` | optional — trips can be planned before dates are known |
| `endDate` | `Date?` | |
| `days` | `[ShootDay]` | `@Relationship(deleteRule: .cascade, inverse: \ShootDay.trip)` |
| `artifacts` | `[TripArtifact]` | `@Relationship(deleteRule: .cascade, inverse: \TripArtifact.trip)` |

### 3.2 `TripArtifact`

The 3-artifact owner workflow, persisted. IDEAS and SHOOT LIST are ingested; SCRIPT is **written by review/export v2** from execution data (bidirectional artifact — see [docs/01-product.md](01-product.md)).

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | `@Attribute(.unique)` |
| `kindRawValue` | `String` | `ideas` \| `shootList` \| `script` |
| `title` | `String` | |
| `body` | `String` | markdown |
| `sourceRawValue` | `String` | `pasted` \| `imported` \| `generated` — script is `generated` |
| `createdAt` | `Date` | |
| `updatedAt` | `Date` | bump on every body write |
| `orderIndex` | `Int` | display order |
| `trip` | `Trip?` | inverse of `Trip.artifacts` |

### 3.3 `ShootDay`

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | `@Attribute(.unique)` |
| `orderIndex` | `Int` | day sequence within trip |
| `date` | `Date?` | optional; unresolved until trip is scheduled |
| `title` | `String` | e.g. "Day 2 — Arashiyama" |
| `notes` | `String` | |
| `windowModeRawValue` | `String` | reuse existing `ShootWindowMode` |
| `startTime` | `Date?` | |
| `endTime` | `Date?` | |
| `currentStopOrderIndex` | `Int` | field-mode cursor at day level |
| `trip` | `Trip?` | inverse of `Trip.days` |
| `stops` | `[Stop]` | `@Relationship(deleteRule: .cascade, inverse: \Stop.day)` |

### 3.4 `Stop`

Replaces `ShootLocation`. Coordinates are **optional** — this removes the need for the P0 required-location-pick stopgap (commit builds `ShootLocation` from picked coordinates at ImportPlanFlowView.swift:495-499) structurally. A stop with nil coordinates renders a **needs-location** badge; `sourceGeoAnchor` keeps the verbatim source line (Google Maps link / address / time-prefix line — see glossary in [docs/00-index.md](00-index.md)) so resolution can be retried anytime without re-importing.

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | `@Attribute(.unique)` |
| `orderIndex` | `Int` | sequence within day |
| `title` | `String` | e.g. "Fushimi Inari — lower gates" |
| `placeName` | `String` | resolvable place string |
| `latitude` | `Double?` | **optional**; nil = needs-location |
| `longitude` | `Double?` | **optional** |
| `sourceGeoAnchor` | `String` | verbatim geo anchor from imported text; `""` if none |
| `plannedArrival` | `Date?` | |
| `plannedDeparture` | `Date?` | |
| `enrichmentJSON` | `String` | migrated role of `ShootLocation.enrichmentJSON` |
| `lastEnrichedAt` | `Date?` | |
| `statusRawValue` | `String` | `upcoming` \| `active` \| `done` \| `skipped` |
| `arrivedAt` | `Date?` | set on field arrival — provenance |
| `departedAt` | `Date?` | set on field departure — provenance |
| `currentStageOrderIndex` | `Int` | field-mode cursor at stop level |
| `day` | `ShootDay?` | inverse of `ShootDay.stops` |
| `stages` | `[Stage]` | `@Relationship(deleteRule: .cascade, inverse: \Stage.stop)` |

### 3.5 `Stage`

The fix for §1.5 problems 1-3. Real identity, persisted `goal`, and a `kind` that gives Story Safety Net a proper target: injection creates or reuses the single `safetyNet` stage on the stop instead of appending 6 hardcoded items to the current stage (FieldView.swift:533-577; the P0 unresolved-title dedup guard already exists at :548-555). Dedup becomes "does this stop's safetyNet stage already have this item title" — and coverage math stays honest because safety-net items are attributable.

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | `@Attribute(.unique)` |
| `orderIndex` | `Int` | sequence within stop |
| `title` | `String` | |
| `goal` | `String` | **the stage mantra line** — what FieldView shows glanceably ([docs/07-field-ux.md](07-field-ux.md)) |
| `kindRawValue` | `String` | `standard` \| `beforeLeaving` \| `safetyNet` |
| `stop` | `Stop?` | inverse of `Stop.stages` |
| `items` | `[CaptureItem]` | `@Relationship(deleteRule: .cascade, inverse: \CaptureItem.stage)` |

Computed (cheap — iterate own `items` only, never regroup): `progress: Double`, `missingItems: [CaptureItem]`, `isStorySafe: Bool` (all `must`-priority and before-leaving items resolved).

### 3.6 `CaptureItem`

Replaces `ShootPlanItem`. Keeps the working field-mode surface; adds provenance; drops denormalization.

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | `@Attribute(.unique)` — **keep** |
| `orderIndex` | `Int` | now scoped per stage — **keep** |
| `title` | `String` | **keep** |
| `guidance` | `String` | **keep** |
| `kindRawValue` | `String` | `shot` \| `voice` \| `sound` \| `transition` \| `note` — **keep** |
| `priorityRawValue` | `String` | `must` \| `optional` — **keep** (non-optional in v2) |
| `isBeforeLeaving` | `Bool` | **keep** |
| `isCaptured` | `Bool` | **keep** |
| `isSkipped` | `Bool` | **keep** |
| `fieldNote` | `String` | **keep** |
| `capturedPhotoData` | `Data?` | `@Attribute(.externalStorage)` — **keep** |
| `capturedPhotoAttachedAt` | `Date?` | **keep** |
| `capturedAt` | `Date?` | **ADD** — when captured; field-verified provenance |
| `skippedAt` | `Date?` | **ADD** — when skipped; provenance |
| `originRawValue` | `String` | **ADD** — `planned` \| `safetyNet` \| `fieldAdded` |
| `sourceLine` | `String` | **ADD** — verbatim imported line this item came from; `""` if not imported. Traceability from field guide back to source text |
| `stage` | `Stage?` | inverse of `Stage.items` — real parent |
| ~~`role`~~ | — | **DROP** — redundant with `kind` (import already writes `kind.title` into it) |
| ~~`stageTitle`~~ / ~~`stageOrderIndex`~~ | — | **DROP** — item has a real parent `Stage` now |

Computed: `kind`, `priority`, `origin` typed accessors; `isResolved` (`isCaptured || isSkipped`).

### 3.7 Retired in v2

`ShootPlan`, `ShootPlanItem`, `ShootLocation`, `FieldGuideStageKey`, and the computed `fieldStages` grouping (ShootPlan.swift:104) are **deleted**, not deprecated. The `FieldGuideDraft` value types are absorbed by the document types (§6): the import editor binds to `ArcPlanDocument` sub-structs instead.

---

## 4. Old → new mapping

Mechanical guide for rewriting `FieldView`, `ShootsView`, `CompletedShootView`, `NewShootFlowView`. A v1 "plan" is a single-location single-session shoot, so it maps to the degenerate trip: one `Trip`, one `ShootDay`, one `Stop`.

| Old (v1) | New (v2) | Notes |
|---|---|---|
| `ShootPlan` | `Trip` + one `ShootDay` + one `Stop` | brief fields (`outputIntent…stylePreset`) → `Trip`; `shootDate`/window fields → `ShootDay`; `storySummary` → `Trip.summary` |
| `ShootPlan.notes` / `rawResponse` / `importedPlanText` | `TripArtifact(kind: shootList).body` | source text becomes a first-class artifact |
| `ShootPlan.isApprovedForField` / `approvedAt` | `Trip.statusRawValue` (`planning` → `active`) | approval collapses into status |
| `ShootPlan.completedAt` | `Trip.statusRawValue = completed` + `Stop.departedAt` | |
| `ShootPlan.currentStageOrderIndex` | `Stop.currentStageOrderIndex` (+ `ShootDay.currentStopOrderIndex`) | cursor moves down the hierarchy |
| `(stageOrderIndex, stageTitle)` group | `Stage` | one row per group; `orderIndex` = old `stageOrderIndex`, `title` = old `stageTitle`; `goal` from draft (was dropped) |
| `ShootPlan.fieldStages` (computed) | `stop.stages.sorted { $0.orderIndex < $1.orderIndex }` | no grouping; SwiftData relationship fetch |
| `FieldGuideStage.progress` / `.missingItems` | `Stage.progress` / `.missingItems` | same semantics, entity-local |
| `ShootPlanItem` | `CaptureItem` | field-by-field per §3.6; `role` dropped; parent is `stage` not `plan` |
| `ShootLocation.name` | `Stop.title` / `Stop.placeName` | |
| `ShootLocation.latitude/longitude` | `Stop.latitude/longitude` (`Double?`) | `0,0` sentinel → `nil` + needs-location badge |
| `ShootLocation.enrichmentJSON` / `lastEnrichedAt` | `Stop.enrichmentJSON` / `lastEnrichedAt` | enrichment pipeline retargets Stop |
| `ShootLocation.status` (computed) | `Stop.statusRawValue` + `Trip.statusRawValue` | persisted, not derived |
| "safety net items appended to current stage" (FieldView.swift:533-577) | items with `origin = safetyNet` in the stop's single `Stage(kind: safetyNet)` | dedup by title within that stage; injection is idempotent |

---

## 5. Store reset strategy (ADR-0003)

- **No SwiftData migration for v1 → v2.** The app is pre-ship; the only store contents are the owner's dev data. Do not write `SchemaMigrationPlan`, do not write `VersionedSchema` for v1.
- The v2 entities have **new class names** (`Trip`, `Stop`, `Stage`, `CaptureItem` vs `ShootPlan`, `ShootLocation`, `ShootPlanItem`), so the rebuild is clean: delete the old model files, register the new schema in `AppContainer`, and delete the store file on first launch after the schema change (or rely on a fresh install).
- **Optional courtesy (recommended, small):** before the wipe, a one-shot debug-menu action that exports each existing `ShootPlan` to an `ArcPlanDocument` JSON file (§6) so dev trips can be re-imported. Best-effort only; do not block P2 on it.
- **ADR-0003 expiry:** the day an external TestFlight build ships, this decision is void — from then on every schema change requires a `SchemaMigrationPlan` and versioned schemas. No external TestFlight build exists or is planned before P3 completes; re-check before starting any schema work.

---

## 6. ArcPlanDocument / ArcGuideDocument (interchange format)

ONE JSON schema, two kinds. `kind: "plan"` = a plan not yet executed (import target, pre-trip sharing). `kind: "guide"` = an executed plan with the `execution` block populated (the raw material for **field-verified** guide badging — see [docs/02-business.md](02-business.md)). Defined in **P1** as the parser output target ([docs/06-import-spec.md](06-import-spec.md)); storage v2 matches it in **P2**; guide export ships in **P4**.

- Types live in `Arc/Core/Documents/`. **That folder must never import SwiftData.** The document is the contract; SwiftData is one storage backend behind it. Mapping code (document ↔ @Model) lives in the feature layer, not in Core/Documents.
- `UTType`: `com.arc.guide`. File extension: `.arcguide`. Declare both in the app target's Info settings in P1 (per [ADR-0004](adr/ADR-0004-arcguide-document-interchange.md); `.arcguide` document-open works from P1 — [docs/06-import-spec.md](06-import-spec.md) §1 row 5); export UI ships in P4.
- The `FieldGuideDraft` value types (§1.4) are absorbed by these document types: the P1 import editor binds directly to mutable document sub-structs, and "commit" persists the document into storage.

### 6.1 Full example (`kind: "plan"`)

```json
{
  "format": "arc.guide",
  "schemaVersion": 1,
  "kind": "plan",
  "generator": "Arc/1.0 (import-t1)",
  "sourceText": "…full pasted/shared text, verbatim…",
  "unparsedRemainder": [],
  "trip": {
    "title": "Kyoto in 4 Days",
    "summary": "Old-Japan atmosphere arc: gates at dawn, bamboo by noon, tea at dusk.",
    "brief": {
      "outputIntent": "fullTravelVlog",
      "captureMedium": "hybrid",
      "targetPlatform": "youtube",
      "stylePreset": "natural"
    },
    "artifacts": [
      { "kind": "ideas", "title": "Ideas", "body": "## Titles\n- I Found Kyoto's Quietest Hour…" },
      { "kind": "shootList", "title": "Shoot List", "body": "…verbatim imported markdown…" }
    ],
    "days": [
      {
        "title": "Day 1 — South Kyoto",
        "date": "2026-10-12",
        "stops": [
          {
            "title": "Fushimi Inari — lower gates",
            "placeName": "Fushimi Inari Taisha",
            "geo": {
              "lat": 34.9671,
              "lon": 135.7727,
              "resolved": true,
              "sourceAnchor": "https://maps.app.goo.gl/abc123"
            },
            "plannedArrival": "2026-10-12T06:00:00+09:00",
            "plannedDeparture": "2026-10-12T08:30:00+09:00",
            "stages": [
              {
                "title": "Arrival",
                "goal": "Empty gates before the crowd — the whole video hinges on this.",
                "kind": "standard",
                "items": [
                  {
                    "title": "Walk-in through first torii, low angle",
                    "guidance": "Hold 8s, let frame breathe.",
                    "itemKind": "shot",
                    "priority": "must",
                    "beforeLeaving": false,
                    "sourceLine": "- MUST: walk-in shot through the first torii (low angle)",
                    "synthetic": false
                  },
                  {
                    "title": "Ambient: morning birds + footsteps on stone",
                    "guidance": "",
                    "itemKind": "sound",
                    "priority": "optional",
                    "beforeLeaving": false,
                    "sourceLine": "- ambient sound of the shrine at dawn"
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  },
  "execution": null
}
```

### 6.2 The `execution` block (`kind: "guide"`)

Populated on export of a completed trip. Keyed by stable ids assigned at export time (array positions mirror `trip.days[].stops[]…`; each stop/item entry carries an `id` matching the entity UUID).

```json
"execution": {
  "executedAt": "2026-10-15T21:04:00+09:00",
  "stops": [
    {
      "id": "6E1C…",
      "arrivedAt": "2026-10-12T05:58:00+09:00",
      "departedAt": "2026-10-12T08:41:00+09:00",
      "items": [
        { "id": "9A2F…", "captured": true, "capturedAt": "2026-10-12T06:04:00+09:00", "skipped": false, "origin": "planned" },
        { "id": "B77D…", "captured": false, "capturedAt": null, "skipped": true, "origin": "safetyNet" }
      ]
    }
  ],
  "coverage": { "mustCaptured": 14, "total": 16, "storySafe": true }
}
```

**Privacy rule:** media — `capturedPhotoData`, photos, `fieldNote` text — is **never** included in a document by default. Only timestamps, flags, origin, and coverage counts. Any future opt-in media export is a separate explicit action, never the default.

### 6.3 Field reference

| Path | Type | Req | Notes |
|---|---|---|---|
| `format` | string | yes | literal `"arc.guide"` |
| `schemaVersion` | integer | yes | see §6.4 |
| `kind` | string | yes | `plan` \| `guide` |
| `generator` | string | yes | producing app/tier, free-form |
| `sourceText` | string | yes | the full pasted/shared text, verbatim — home of invariant 1 in [docs/06-import-spec.md](06-import-spec.md) (the shootList artifact `body` may carry the same markdown for display) |
| `unparsedRemainder` | array of string | no | source lines no tier could place — tier contract rule 2 in [docs/06-import-spec.md](06-import-spec.md); empty when every line is accounted for |
| `trip.title` / `trip.summary` | string | yes / no | |
| `trip.brief.*` | string | no | raw values of the four brief enums |
| `trip.artifacts[]` | array | no | `kind` (`ideas` \| `shootList` \| `script`), `title`, `body` (markdown) |
| `trip.days[].title` | string | yes | |
| `trip.days[].date` | string | no | ISO-8601 date |
| `…stops[].title` / `placeName` | string | yes / no | |
| `…stops[].geo` | object | no | `lat`/`lon` (number, null when unresolved), `resolved` (bool), `sourceAnchor` (string, verbatim) |
| `…stops[].plannedArrival` / `plannedDeparture` | string | no | ISO-8601 datetime |
| `…stages[].title` / `goal` | string | yes / no | `goal` = stage mantra |
| `…stages[].kind` | string | yes | `standard` \| `beforeLeaving` \| `safetyNet` |
| `…items[].title` | string | yes | |
| `…items[].guidance` / `sourceLine` | string | no | |
| `…items[].itemKind` | string | yes | `shot` \| `voice` \| `sound` \| `transition` \| `note` |
| `…items[].priority` | string | yes | `must` \| `optional` |
| `…items[].beforeLeaving` | bool | no | default false |
| `…items[].synthetic` | bool | no | default false; **required `true` when `sourceLine` is absent** (auto leaving-transition, tier-invented items) — the explicit synthetic marker of contract rule 3 / invariant 2 in [docs/06-import-spec.md](06-import-spec.md), enforced at document validation |
| `execution` | object\|null | yes | null for `kind: plan`; §6.2 shape for `kind: guide` |

### 6.4 Versioning rules

- `schemaVersion` is an **integer**, starting at `1`.
- **Additive** changes (new optional fields) do **not** bump the version. Decoders must ignore unknown fields without failing.
- **Breaking** changes (rename, removal, semantics change) bump the version, and the release that bumps it ships an N-1 → N upgrade decoder (read old, emit new in memory). Never require re-import for a version bump.
- Preserve unknown fields on round-trip where feasible (decode-edit-encode should not silently drop keys another producer added).
- Reject documents where `format != "arc.guide"` or `schemaVersion` is greater than the highest version this build understands; surface a clear "update Arc" message, never a silent partial parse.

### 6.5 Sequencing

| Phase | Document role |
|---|---|
| P1 | Types defined in `Arc/Core/Documents/`; T0/T1/T2 parsers ([docs/06-import-spec.md](06-import-spec.md)) all emit `ArcPlanDocument`; import editor binds to it; storage still v1 (commit flattens document → `ShootPlan`/`ShootPlanItem`) |
| P2 | Storage v2 mirrors the document shape; document ↔ entity mapping becomes near-mechanical; debug export of old plans (§5) uses it |
| P3 | Review reads execution data that will populate the `execution` block |
| P4 | `.arcguide` export + share preview ships; `kind: guide` documents leave the device |
