# 08 — Roadmap

> **Agent Brief** — Status: Current | Applies to: All phases | Owner doc for: build order, phase scope, binding phase non-goals, acceptance criteria — this doc governs what to build NOW.
> Read [docs/00-index.md](00-index.md) first. Behavioral rules: /AGENTS.md (wins on conduct). Current build phase: the status tracker below.
> Code pointers verified against `task-owner-mvp-through-p4` after owner-test MVP implementation (2026-07-07). Re-verify line numbers before editing.

---

## Status tracker

| Phase | Title | Gate to start | Status |
|-------|-------|---------------|--------|
| P0 | Stabilize | None | **Done on main** — tests green |
| P1 | Import pipeline v2 + document format | P0 done | **Done on main** — tests green |
| P2 | Schema v2 + timeline and map | P1 done | **In review on `task-owner-mvp-through-p4`** — Trip schema, direct commit paths, trip list, timeline, map, stop/stage execution, and retired model deletion implemented; manual owner checks pending |
| P3 | Field ergonomics v2 + review/export v2 | G1 — see [docs/02-business.md](02-business.md) | **Owner-test subset in review** — stage mantra, safety-net stage, script artifact generation, and review summary implemented; golden-hour, geofence, and Live Activity remain gated/not started |
| P4 | Guide export + share preview + email capture | G2 — see [docs/02-business.md](02-business.md) | **Local export subset in review** — in-app `.arcguide` export/import round-trip implemented; off-app web preview and email capture remain gated/not started |
| P5 | Platform | Docs: may run parallel with P4. Build: G3 + G4 — see [docs/02-business.md](02-business.md) | Not started |

Update the Status column in the same PR that completes a phase's "Done when" list. Never mark a phase started while its gate is unmet.

### Working-tree status (2026-07-07, branch `task-owner-mvp-through-p4`)

`main` has been fast-forwarded and pushed through P0/P1. The current branch starts from that updated `main` and implements the owner-test MVP loop across schema v2 plus local review/export:

- `Trip`, `TripArtifact`, `ShootDay`, `Stop`, `Stage`, and `CaptureItem` are the active SwiftData model.
- Import commits `ArcPlanDocument` / `.arcguide` documents directly into a `Trip` graph.
- The list, field, info, editor, completed review, enrichment/cache adapters, and preview/test doubles are refit to `Trip`/`Stop`.
- Field execution supports timeline, map, stop switching, stage advancement, capture/skip/photo/note, safety-net stage insertion, and completion.
- Completion generates a `TripArtifact(kind: script)` and the completed screen exports markdown plus a structured `.arcguide` file.
- `.arcguide` import uses `ArcDocumentCodec.decodePlanOrGuide` and can become a fresh runnable trip.
- Retired files deleted: `ShootLocation.swift`, `ShootPlan.swift`, and `PlanViewModel.swift`.

Current verification:

- **Build + tests green (2026-07-07).** `xcodebuild test -scheme Arc -project Arc.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/ArcDerivedData` reports `TEST SUCCEEDED`.
- Test coverage includes document codec round-trip/validation, AFP parser fixtures, 8-fixture import corpus, and schema-v2 document-to-trip/export round-trip mapper coverage.

Remaining manual owner checks before merging this branch:

- Import a real multi-stop plan, execute at least two stops, complete the trip, and confirm the generated script is useful enough to edit from.
- Export the completed `.arcguide`, re-import it as a fresh trip, and verify stop/stage/item structure and execution reset are correct.
- Verify unresolved imported stops with only `sourceGeoAnchor` are usable and can be assigned a precise location in the info/editor flow.
- Confirm repeated Safety Net taps do not duplicate template items on the same stop.

Important scope boundary: this branch gives the owner a local MVP to test. It does **not** complete the gated P4 business stack: web map preview, ESP-hosted email capture, video-description link flow, or second-person email-gated validation.

---

## Rules of engagement

1. **Precedence** (defined in [docs/00-index.md](00-index.md)): AGENTS.md governs HOW agents work; docs/ governs WHAT to build; this doc governs what to build NOW; **phase non-goals beat everything** — an "Out of scope" entry below overrides any suggestion elsewhere in docs/.
2. **Gates**: G1–G4 are channel milestones, never calendar dates. The gates table lives ONLY in [docs/02-business.md](02-business.md); this doc references gates by ID and never redefines them.
3. **Sizing**: every in-scope work item is scoped to 1–3 agent-days. If an item grows past 3 agent-days during implementation, split it and record the split here.
4. **Quality track**: the parsing eval corpus and test suite ([docs/09-quality.md](09-quality.md)) grow in every phase. Corpus green is a merge requirement from P0 onward. See [Cross-cutting quality track](#cross-cutting-quality-track-starts-p0-never-ends).
5. **Line numbers**: file pointers below drift as phases land. Re-verify before editing; do not trust historical line references blindly.

---

## P0 — Stabilize

### Goal

Make the existing import → field → complete golden path truthful (no fake data, no silent data loss, no duplicate safety-net items) and put a test harness under the parser, without changing the schema.

### Gate to start

None. P0 is complete on `main`.

### In scope

- [x] **Commit the field-guide/import work**.
- [x] **Add transitional `stageGoal` stopgap and surface it**. Superseded by P2 schema v2; `Stage.goal` is now persisted directly.
- [x] **Replace fake location commit with truthful location handling**. Superseded by P2 optional `Stop` coordinates plus `sourceGeoAnchor`.
- [x] **Safety-net dedup**. Superseded by P2/P3 structured `Stage(kind: safetyNet)` with `CaptureItem.origin`.
- [x] **Create the `ArcTests` target**.
- [x] **Unit tests for `ImportedPlanParser` + first 8 corpus fixtures**.

### Out of scope (BINDING)

- Any schema change beyond the single transitional `stageGoal` field. No new entities, no relationship changes, no migrations.
- Foundation Models / T1 work of any kind. That is P1.
- UI redesign. Cosmetic-only changes ride along at zero cost or not at all.

### Done when

- [x] Clean build and green tests on the `ArcTests` target.
- [x] Golden path model defects fixed, then superseded by schema v2.
- [x] Tapping Story Safety Net twice does not duplicate items in scope.
- [x] Parser corpus asserts stage / kind / priority / before-leaving detection and passes.

---

## P1 — Import pipeline v2 + document format

### Goal

Introduce the ArcPlanDocument/ArcGuideDocument interchange format and a tiered import pipeline (T0 heuristics, T1 on-device Foundation Models, T2 opt-in cloud) that parses real trip plans into structured days/stops/geo anchors.

### Gate to start

P0 done (all P0 "Done when" boxes checked).

### In scope

- [x] **`ArcPlanDocument` / `ArcGuideDocument` structs + codec + fixtures**.
- [x] **Parser v2 (T0) evolving `ImportedPlanParser`**.
- [x] **T1: `Arc/Services/AI/FoundationModelsPlanService.swift`**.
- [x] **Refit `ImportedPlanGenerator` as T2**.
- [x] **Commit path: document → storage**. Current branch maps directly into schema-v2 `Trip` through `TripDocumentMapper`.
- [x] **Ingestion surfaces** for app intent/handoff/open-in flows needed by owner-test MVP.
- [x] **Corpus baseline** with 8 fixtures. Continue adding real-trip fixtures as dogfood finds gaps.

### Out of scope (BINDING)

- Historical P1 did not own schema changes, timeline/map, or export UI. Those are now covered by the owner-test MVP branch where explicitly noted above.

### Done when

- [x] Sharing/opening supported inputs reaches the import editor path.
- [ ] T1 device-quality evaluation still needs physical-device dogfood notes.
- [x] Geo anchors survive from source text through parse and commit.
- [x] ChatGPT-template output parses on T0.
- [x] Corpus green.

---

## P2 — Schema v2 + timeline and map

### Goal

Replace the flat ShootLocation/ShootPlan/ShootPlanItem model with schema v2 (Trip → ShootDay → Stop → Stage → CaptureItem, plus TripArtifact) and give trips a day timeline and map, deleting every P0/P1 stopgap.

### Gate to start

P1 done (all P1 "Done when" boxes checked).

### In scope

- [x] **Schema v2 entities** (2–3 agent-days). New folder `Arc/Features/Trips/Domain/`. Entities exactly per [docs/05-data-model.md](05-data-model.md): `Trip`, `TripArtifact` (kinds: `ideas | shootList | script`), `ShootDay`, `Stop` (with `sourceGeoAnchor`), `Stage` (kinds: `standard | beforeLeaving | safetyNet`, persisted `goal`), `CaptureItem` (origin: `planned | safetyNet | fieldAdded`).
- [ ] **Store reset per [docs/adr/ADR-0003-store-reset-pre-ship.md](adr/ADR-0003-store-reset-pre-ship.md)** (1 agent-day). No migration from v1 — wipe and rebuild. Add an optional pre-wipe JSON export debug action so the owner can dump existing data before the reset.
- [x] **Rewrite both commit paths**. `ImportPlanFlowView` commits `ArcPlanDocument → Trip`; `NewShootFlowView` commits a single-stop `Trip`.
- [x] **Rewrite reads**. `ShootsView`, `FieldView`, `CompletedShootView`, `PlanEditorSheet`, and `ShootInfoSheet` are Trip-backed.
- [x] **Day timeline UI**. Ordered stops render in field mode with status.
- [x] **MapKit day map**. Resolved stops render on a map; unresolved stops keep needs-location state.
- [x] **Stop-level navigation**. Arrive → execute stages → depart → next stop writes stop provenance.
- [ ] **Partial: `TripArtifact` storage + paste-in UI**. Storage and generated script/shoot-list artifacts exist; dedicated paste-in artifact editors remain backlog.
- [x] **Delete every stopgap**. `CaptureItem.origin` replaces transitional markers and retired model types are deleted.

### Out of scope (BINDING)

- Geofencing, golden hour, Live Activities. That is P3 (and ADR-0007 constrains it).
- External guide preview/email capture. Local `.arcguide` export is pulled into the owner-test MVP.
- Any sync or backend. See [docs/adr/ADR-0005-backend-deferred-cloudkit-first.md](adr/ADR-0005-backend-deferred-cloudkit-first.md).

### Done when

- [ ] A real 2-day, 5-stop plan imports and shows two days, with timeline and map rendering all resolved stops in order. Manual owner check pending.
- [ ] Executing stop 2 does not disturb stop 3. Manual owner check pending.
- [x] Stage goal is visible in field mode, read from persisted `Stage.goal`; the transitional stopgap no longer exists.
- [ ] Partial: ideas and script artifacts attach to a trip and persist across relaunch. Script and shoot-list artifacts exist; dedicated ideas paste-in editor remains backlog.
- [x] All P0/P1 tests are green against the document → storage mapper.
- [x] Retired model types no longer exist in app/test code.

---

## P3 — Field ergonomics v2 + review/export v2

### Goal

Make field mode truly glanceable (stage mantra, one-tap confirm, story-is-safe state) and make review generate the script artifact — shaped by the pain list from real trips.

### Gate to start

**G1 — dogfood proven**; definition in [docs/02-business.md](02-business.md). The pain list from those trips drives final scoping of this phase: re-rank the items below against it before starting.

### In scope

- [ ] **Glanceable stage card** (2–3 agent-days). Per [docs/07-field-ux.md](07-field-ux.md): stage mantra (Stage.goal + musts remaining), one-tap confirm, minimal scrolling. Files: `Arc/Features/Field/Presentation/` (post-P2 layout).
- [ ] **Story-is-safe / done-enough state** (1–2 agent-days). All must-priority and before-leaving items resolved (captured or skipped) in scope → distinct, calm visual state. Burnout-aware, never guilt. Definition in [docs/07-field-ux.md](07-field-ux.md).
- [ ] **Golden-hour nudges** (1–2 agent-days). Per stop, using `Arc/Services/Enrichment/SunMoonCalculator.swift` + `OpenMeteoAPIClient.swift`. Unit-tested against known stop/date pairs.
- [ ] **Geofenced stop surfacing (while-in-use) + Live Activity** (2–3 agent-days). Surface the next stop when nearby, while-in-use authorization only; Live Activity shows the stage mantra on the lock screen. Constraints and the scoped AGENTS.md:30 amendment: [docs/adr/ADR-0007-while-in-use-location-surfacing.md](adr/ADR-0007-while-in-use-location-surfacing.md).
- [ ] **Review/export v2: coverage stats** (1–2 agent-days). Coverage per stop and per day (musts captured/skipped, safety-net usage) in the trip summary.
- [ ] **Edit-outline generator → `TripArtifact(kind: script)`** (2–3 agent-days). Chronological via `capturedAt`; voice/sound/transition cues called out explicitly; the script artifact is bidirectional (owner edits flow back in).
- [ ] **Markdown export + `.arcguide` groundwork** (1–2 agent-days). Replace the plain-text `ShareLink` in `CompletedShootView` with structured markdown export; wire the completed-trip → `ArcGuideDocument` mapping (export UI ships in P4).
- [ ] **Resolve the Flickr reference-image debt** (1 agent-day). Reference images are cached to disk (`DiskReferenceImageCache`) but never displayed in any view. Decide during the phase: surface them in stop detail, or retire the pipeline. Either outcome closes the debt; record the decision in this doc.

### Out of scope (BINDING)

- Web preview, email capture, publishing. That is P4.
- Accounts of any kind. That is P5, gated on G3 + G4.

### Done when

- [ ] A full stop is executable without scrolling, verified in bright outdoor light on device.
- [ ] Done-enough state is reachable in a real run and visually distinct from both "in progress" and "everything captured".
- [ ] Golden-hour nudge is unit-tested against `SunMoonCalculator` for a known stop/date and fires correctly on device.
- [ ] Lock-screen Live Activity shows the current stage mantra and updates when the stage advances.
- [ ] Completing a trip generates a script artifact that the owner actually uses to edit a video.

---

## P4 — Guide export + share preview + email capture

### Goal

Turn a completed trip into a shareable, field-verified `.arcguide` with a web map preview gated on email capture — the first business asset.

### Gate to start

**G2 — channel live**; definition in [docs/02-business.md](02-business.md).

### In scope

- [ ] **`.arcguide` export from completed trips** (2–3 agent-days). `ArcGuideDocument` with `kind: guide`, execution summary, and a field-verified block (X/Y musts captured, dates, stops completed) — rendered in-app and embedded in the export. Media excluded by default. Format: [docs/05-data-model.md](05-data-model.md) + [docs/adr/ADR-0004-arcguide-document-interchange.md](adr/ADR-0004-arcguide-document-interchange.md).
- [ ] **Share sheet + file handling** (1 agent-day). Export via share sheet and to Files using the `com.arc.guide` UTType registered in P1.
- [ ] **Off-app minimal stack** (2–3 agent-days). Per [docs/02-business.md](02-business.md) and [docs/adr/ADR-0006-email-capture-and-paid-guides.md](adr/ADR-0006-email-capture-and-paid-guides.md): static preview page rendering the guide JSON as map + stop list; ESP-hosted email gate (free itinerary per video, gated on email); open-in-Arc deep link. Deliberately boring hosting. No custom backend. No server storing user data.
- [ ] **Import `.arcguide` back into Arc as a runnable trip** (1–2 agent-days). Buyer-side dry run and free round-trip format testing: an imported guide becomes a fresh, executable `Trip`.

### Out of scope (BINDING)

- Payments. Gated on G4; P5 docs first.
- Accounts. P5.
- In-app guide store or marketplace of any kind. Arc is the execution + provenance layer, not a marketplace — see [docs/03-market-research.md](03-market-research.md).

### Done when

- [ ] Full loop verified with a real second person: complete trip → export → link in a video description → they open the map preview → enter email → open the guide in Arc → it runs as a fresh trip.
- [ ] Export → import round-trip is lossless for `kind: guide` (fixture-verified).
- [ ] `schemaVersion` upgrade path proven with a v-next fixture (a version-N+1 document is either handled or rejected gracefully with a clear message).

---

## P5 — Platform

### Goal

Produce implementation-ready platform docs (accounts/sync, guide distribution, payments) so that when G3 + G4 trip, an agent can start building from the docs alone.

### Gate to start

**Docs work** may run in parallel with P4. **Build work** is gated on **G3 — audience signal** AND **G4 — willingness-to-pay**; definitions in [docs/02-business.md](02-business.md).

### In scope

- [ ] **Finalize [docs/adr/ADR-0005-backend-deferred-cloudkit-first.md](adr/ADR-0005-backend-deferred-cloudkit-first.md)** (1–2 agent-days). Accounts/sync candidate shapes; CloudKit-first evaluation against actual P0–P4 usage data.
- [ ] **Finalize [docs/adr/ADR-0006-email-capture-and-paid-guides.md](adr/ADR-0006-email-capture-and-paid-guides.md)** (1–2 agent-days). Guide distribution and purchase flows; IAP vs web checkout; creator payout shape; buyer-app-free principle (a buyer must get value from the preview without installing Arc).
- [ ] **Write the platform section of [docs/04-architecture.md](04-architecture.md)** (1–2 agent-days). Candidate architectures, decision criteria, and the migration path from the P4 static stack.

### Out of scope (BINDING)

- Any platform code in the app before G3 + G4 trip. No account models, no sync scaffolding, no payment SDKs, no server code.

### Done when

- [ ] An agent could start P5 implementation from the docs alone (entities, flows, and decision criteria are specific enough to build against without this conversation).
- [ ] Zero platform code exists in the app while the gates remain untripped.

---

## Cross-cutting quality track (starts P0, never ends)

Owner doc: [docs/09-quality.md](09-quality.md).

| Rule | Detail |
|------|--------|
| Corpus growth | The parsing eval corpus and its tests grow in **every** phase and with **every** real trip imported. P0: 5–8 fixtures. P1: ~20. P2+: add a fixture for each new real trip and each parser bug found in the field. |
| Merge requirement | Corpus green is a merge requirement from P0 onward. A PR that breaks a fixture either fixes the parser or updates the fixture with a recorded justification. |
| Real-trip feedback | After each real trip (G1 progress), import the actual source notes as a fixture before fixing whatever failed. The fixture is the bug report. |
| Test target | `ArcTests` (created in P0) hosts parser tests, document codec round-trips, mapper tests, and golden-hour/date math tests as phases add them. |

---

## Related docs

| Doc | Why you'd read it from here |
|-----|------------------------------|
| [docs/02-business.md](02-business.md) | The gates table (G1–G4) — single source of truth; never duplicated here. |
| [docs/05-data-model.md](05-data-model.md) | Schema v2 entities and the ArcPlanDocument/ArcGuideDocument field spec. |
| [docs/06-import-spec.md](06-import-spec.md) | Import tiers T0–T3, AFP conventions, chunking and fallback behavior. |
| [docs/07-field-ux.md](07-field-ux.md) | Glanceable field mode, stage mantra, story-is-safe definitions. |
| [docs/09-quality.md](09-quality.md) | Corpus layout, eval thresholds, test target conventions. |
| [docs/adr/](adr/) | Decision records referenced by phase items above. |
