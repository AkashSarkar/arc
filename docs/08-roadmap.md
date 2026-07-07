# 08 — Roadmap

> **Agent Brief** — Status: Current | Applies to: All phases | Owner doc for: build order, phase scope, binding phase non-goals, acceptance criteria — this doc governs what to build NOW.
> Read [docs/00-index.md](00-index.md) first. Behavioral rules: /AGENTS.md (wins on conduct). Current build phase: the status tracker below.
> Code pointers verified against ux-redesign @ abce4bc + uncommitted field-guide work (2026-07-06). Re-verify line numbers before editing.

---

## Status tracker

| Phase | Title | Gate to start | Status |
|-------|-------|---------------|--------|
| P0 | Stabilize | None | **In progress** — implemented, uncommitted (see working-tree status below) |
| P1 | Import pipeline v2 + document format | P0 done | **In progress** — implemented, uncommitted (see working-tree status below) |
| P2 | Schema v2 + timeline and map | P1 done | Not started |
| P3 | Field ergonomics v2 + review/export v2 | G1 — see [docs/02-business.md](02-business.md) | Not started |
| P4 | Guide export + share preview + email capture | G2 — see [docs/02-business.md](02-business.md) | Not started |
| P5 | Platform | Docs: may run parallel with P4. Build: G3 + G4 — see [docs/02-business.md](02-business.md) | Not started |

Update the Status column in the same PR that completes a phase's "Done when" list. Never mark a phase started while its gate is unmet.

### Working-tree status (2026-07-07, branch `task-p0-p1-import-stabilization`)

Uncommitted implementation of most P0 + P1 work items exists on this branch: parser v2 emitting `ArcPlanDocument` (day/stop/geo-anchor detection), `Arc/Core/Documents/ArcDocuments.swift` codec, `Arc/Services/AI/FoundationModelsPlanService.swift`, `ImportPlanIntent` + `ImportHandoff` (share/App Intent ingestion), the P0 defect fixes (required location pick, persisted `stageGoal`, safety-net dedup), and `ArcTests` with an 8-fixture import corpus.

State when work paused:

- **Build + tests green (2026-07-07).** `xcodebuild test` on the iPhone 17 Pro (iOS 26.5) simulator reports `TEST SUCCEEDED`; all 6 `ArcTests` cases pass (codec round-trip, unknown-field tolerance, future-schema rejection, AFP template parsing, draft mapping, 8-fixture import corpus).
- **Swift concurrency convention.** The project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; pure domain/document/parser types are marked `nonisolated` (applied across `FieldGuide.swift`, `ImportHandoff.swift`, `ArcDocuments.swift`, `ImportedPlanParser.swift`, `ImportedPlanGenerator.swift` extensions, `ImportPlanIntent.swift`, and the `ArcTests` files). Follow this convention for any new pure-logic type.
- **Parser notes:** kind inference matches "ambien"/"ambian" stems; digit-less comma addresses ("Rua da Conceição, Lisboa") are accepted as geo anchors only while a stop awaits its first anchor (`isLikelyAddressLine`).
- **Corpus loader quirk:** the synchronized `ArcTests` group flattens fixture resources into the test-bundle root; `ImportCorpusTests.loadFixtures()` falls back to the bundle root (and `urls(forResourcesWithExtension:subdirectory:)` returns an empty array, not nil, for a missing subdirectory).
- **Remaining before ticking P0/P1 "Done when" boxes:** the boxes below still track against their acceptance criteria — re-run the full test command above after any change, and confirm the golden-path items that require manual device/simulator interaction (real location pick on import, safety-net double-tap, share-sheet ingestion).

---

## Rules of engagement

1. **Precedence** (defined in [docs/00-index.md](00-index.md)): AGENTS.md governs HOW agents work; docs/ governs WHAT to build; this doc governs what to build NOW; **phase non-goals beat everything** — an "Out of scope" entry below overrides any suggestion elsewhere in docs/.
2. **Gates**: G1–G4 are channel milestones, never calendar dates. The gates table lives ONLY in [docs/02-business.md](02-business.md); this doc references gates by ID and never redefines them.
3. **Sizing**: every in-scope work item is scoped to 1–3 agent-days. If an item grows past 3 agent-days during implementation, split it and record the split here.
4. **Quality track**: the parsing eval corpus and test suite ([docs/09-quality.md](09-quality.md)) grow in every phase. Corpus green is a merge requirement from P0 onward. See [Cross-cutting quality track](#cross-cutting-quality-track-starts-p0-never-ends).
5. **Line numbers**: file pointers below were verified 2026-07-06 against ux-redesign @ abce4bc plus the uncommitted field-guide work. Re-verify before editing; do not trust them blindly after P0 lands.

---

## P0 — Stabilize

### Goal

Make the existing import → field → complete golden path truthful (no fake data, no silent data loss, no duplicate safety-net items) and put a test harness under the parser, without changing the schema.

### Gate to start

None. P0 is the current phase.

### In scope

- [ ] **Commit the uncommitted field-guide/import work** (0.5–1 agent-day). Files: `Arc/Features/Planning/Domain/FieldGuide.swift`, `Arc/Features/Planning/Domain/ImportedPlanParser.swift`, `Arc/Features/Planning/Domain/ImportedPlanGenerator.swift`, `Arc/Features/Shoots/Presentation/ImportPlanFlowView.swift`. Land as-is (with build fixes only) so subsequent P0 items diff against committed code.
- [x] **Add transitional `stageGoal: String` to `ShootPlanItem`** (1–2 agent-days) — implemented, pending commit. File: `Arc/Features/Planning/Domain/ShootPlan.swift` (`stageGoal` at `:173`). Denormalized per item exactly like the existing `stageTitle` (stages are computed by grouping on `(stageOrderIndex, stageTitle)` — `fieldStages` at `ShootPlan.swift:104`). This stopped the data loss where the stage goal was editable in the import UI but dropped at commit. This field is a stopgap; it is **deleted in P2** when `Stage.goal` becomes a real persisted property.
- [x] **Persist and surface the stage goal** (included in item above; keep both in one PR) — implemented, pending commit. `stageGoal` is persisted in `ImportPlanFlowView.commitImportedPlan()` — item loop at `ImportPlanFlowView.swift:522-545` — and surfaced in the `FieldView` stage header (goal shown at `FieldView.swift:659-660`, `:724-725`) so the field mantra (Stage.goal + musts remaining) has a real goal to show.
- [x] **Replace the fake location commit with a required location-pick step** (1–2 agent-days) — implemented, pending commit. The import flow requires a picked real location before commit and builds the `ShootLocation` from its coordinates (`ImportPlanFlowView.swift:495-499`), reusing the existing picker components in `Arc/Features/Locations`. Plans are only reachable through their `ShootLocation`, so a nil location is not an option before P2 — the pick is required, not optional.
- [x] **Safety-net dedup in `FieldView.addSafetyNetItems()`** (1 agent-day) — implemented, pending commit. File: `FieldView.swift:533-577`. Skips any draft whose title already exists **unresolved** in the current stage (dedup at `:548-555`; resolved = captured or skipped). Added items carry the transitional `"Safety Net"` role marker (`:559`) so they are identifiable; the real `CaptureItem.origin` field (`planned | safetyNet | fieldAdded`) arrives in P2 and replaces this marker.
- [ ] **Create the `ArcTests` target** (0.5 agent-day). No test target exists today. Wire it into the scheme so `xcodebuild test` runs on simulator; see [docs/09-quality.md](09-quality.md) for target layout and naming.
- [ ] **Unit tests for `ImportedPlanParser` + first 5–8 corpus fixtures** (1–2 agent-days). Fixtures and assertion shape per [docs/09-quality.md](09-quality.md); cover the Arc-Flavored Plan (AFP) conventions in [docs/06-import-spec.md](06-import-spec.md). Assertions must include stage detection, item kind, priority (Must tiers), and before-leaving detection.

### Out of scope (BINDING)

- Any schema change beyond the single transitional `stageGoal` field. No new entities, no relationship changes, no migrations.
- Foundation Models / T1 work of any kind. That is P1.
- UI redesign. Cosmetic-only changes ride along at zero cost or not at all.

### Done when

- [ ] Clean build and green tests on the `ArcTests` target.
- [ ] Golden path works end to end: import (paste) → field execution → complete, with a real user-picked location (no `0,0` coordinates in the store) and a persisted stage goal visible in the `FieldView` stage header.
- [ ] Tapping Story Safety Net twice does not duplicate items in the stage.
- [ ] Parser corpus (5–8 fixtures) asserts stage / kind / priority / before-leaving detection and passes.

---

## P1 — Import pipeline v2 + document format

### Goal

Introduce the ArcPlanDocument/ArcGuideDocument interchange format and a tiered import pipeline (T0 heuristics, T1 on-device Foundation Models, T2 opt-in cloud) that parses real trip plans into structured days/stops/geo anchors — while still committing into the existing flat model.

### Gate to start

P0 done (all P0 "Done when" boxes checked).

### In scope

- [ ] **`ArcPlanDocument` / `ArcGuideDocument` structs + codec + fixtures** (2–3 agent-days). New folder `Arc/Core/Documents/` — this folder must never import SwiftData. ONE JSON schema, `kind: plan | guide`, integer `schemaVersion` starting at 1, `UTType com.arc.guide`, file extension `.arcguide`. Field-level spec lives in [docs/05-data-model.md](05-data-model.md); interchange rationale in [docs/adr/ADR-0004-arcguide-document-interchange.md](adr/ADR-0004-arcguide-document-interchange.md). Include round-trip encode/decode tests with fixtures.
- [ ] **Parser v2 (T0) evolving `ImportedPlanParser`** (2–3 agent-days). File: `Arc/Features/Planning/Domain/ImportedPlanParser.swift`. Add day-heading detection, stop detection, and geo-anchor extraction (Google Maps URLs, addresses, time-prefix lines — preserved verbatim per the glossary in [docs/00-index.md](00-index.md)). Output becomes `ArcPlanDocument`. T0 always runs and is the universal fallback + per-day chunker per [docs/06-import-spec.md](06-import-spec.md) and [docs/adr/ADR-0001-tiered-import.md](adr/ADR-0001-tiered-import.md).
- [ ] **T1: new `Arc/Services/AI/FoundationModelsPlanService.swift`** (2–3 agent-days). Apple Foundation Models `@Generable` structures mirroring the document. Availability-gated via `SystemLanguageModel`; 4,096-token window → chunk per T0-detected day; prewarm on the import screen; any guardrail violation falls back silently to T0. Behavior spec: [docs/06-import-spec.md](06-import-spec.md).
- [ ] **Refit `ImportedPlanGenerator` as T2** (1 agent-day). File: `Arc/Features/Planning/Domain/ImportedPlanGenerator.swift`. Keep the existing OpenAI-compatible path (`Arc/Services/AI/OpenAICompatibleAIService.swift`), user opt-in, never a dependency; change its output to `ArcPlanDocument`.
- [ ] **Commit path: document → existing flat model** (1–2 agent-days). Map `ArcPlanDocument` into `ShootPlan`/`ShootPlanItem` in `ImportPlanFlowView`. Multi-stop days collapse into prefixed stage titles like `"Stop 2 · Harbor — Arrival"`. Geo anchors must be carried into the committed data. This mapping is documented as **temporary** in [docs/05-data-model.md](05-data-model.md) and is deleted in P2.
- [ ] **Ingestion surfaces** (2–3 agent-days). Share extension target accepting `.txt`/`.md` plus PDF text extraction, handing off via App Group; document-type registration so Arc opens plan files from Files; `ImportPlanIntent` App Intent plus a "Send Note to Arc" shortcut recipe (documented in [docs/06-import-spec.md](06-import-spec.md)).
- [ ] **Corpus grows to ~20 fixtures** (1–2 agent-days). Add day/stop/geo-anchor assertions per [docs/09-quality.md](09-quality.md), including at least one ChatGPT-template fixture and one messy freeform Apple Notes fixture.

### Out of scope (BINDING)

- SwiftData schema changes. The flat model stays until P2.
- Map or timeline UI. That is P2.
- Document **export** UI. Export is P3 groundwork / P4 feature; P1 only reads and writes the format internally and in tests.

### Done when

- [ ] Sharing a `.md` from Files or Notes opens the import editor pre-parsed into days/stops.
- [ ] The T1 Foundation Models tier measurably improves at least one messy fixture over T0 (per the eval harness in [docs/09-quality.md](09-quality.md)) and silently falls back when unavailable — verified with an airplane-mode device test.
- [ ] Geo anchors survive from source text through parse and commit (verbatim strings present in the committed data).
- [ ] ChatGPT-template output (the owner's standard prompt output per [docs/06-import-spec.md](06-import-spec.md)) parses 100 percent on T0 alone.
- [ ] Eval thresholds in [docs/09-quality.md](09-quality.md) met; corpus green.

---

## P2 — Schema v2 + timeline and map

### Goal

Replace the flat ShootLocation/ShootPlan/ShootPlanItem model with schema v2 (Trip → ShootDay → Stop → Stage → CaptureItem, plus TripArtifact) and give trips a day timeline and map, deleting every P0/P1 stopgap.

### Gate to start

P1 done (all P1 "Done when" boxes checked).

### In scope

- [ ] **Schema v2 entities** (2–3 agent-days). New folder `Arc/Features/Trips/Domain/`. Entities exactly per [docs/05-data-model.md](05-data-model.md): `Trip`, `TripArtifact` (kinds: `ideas | shootList | script`), `ShootDay`, `Stop` (with `sourceGeoAnchor`), `Stage` (kinds: `standard | beforeLeaving | safetyNet`, persisted `goal`), `CaptureItem` (origin: `planned | safetyNet | fieldAdded`).
- [ ] **Store reset per [docs/adr/ADR-0003-store-reset-pre-ship.md](adr/ADR-0003-store-reset-pre-ship.md)** (1 agent-day). No migration from v1 — wipe and rebuild. Add an optional pre-wipe JSON export debug action so the owner can dump existing data before the reset.
- [ ] **Rewrite both commit paths** (2–3 agent-days). `ImportPlanFlowView` commits `ArcPlanDocument → Trip` graph directly (deletes the P1 flat-model mapper and the `"Stop 2 · …"` title-prefix collapse). `NewShootFlowView` commits a single-stop `Trip`.
- [ ] **Rewrite reads** (2–3 agent-days). `ShootsView` → trips list; `FieldView` → stage-of-stop execution (deletes the computed `fieldStages` grouping at `ShootPlan.swift:104`); `CompletedShootView` → trip summary; `PlanEditorSheet` / `ShootInfoSheet` refits.
- [ ] **Day timeline UI** (1–2 agent-days). Ordered stops per `ShootDay` with status and times.
- [ ] **MapKit day map** (1–2 agent-days). Numbered stop annotations; needs-location badge for stops whose geo anchor is unresolved.
- [ ] **Stop-level navigation** (1–2 agent-days). Arrive → execute stages → depart → next stop, writing `arrivedAt` / `departedAt` on `Stop`.
- [ ] **`TripArtifact` storage + paste-in UI** (1–2 agent-days). Attach ideas and script artifacts to a `Trip`; paste-in editors for `ideas` and `script` kinds (script generation itself is P3).
- [ ] **Delete every stopgap** (1 agent-day). `CaptureItem.origin` replaces the P0 transitional safety-net marker; delete the `stageGoal` field on `ShootPlanItem`, `FieldGuideStageKey`, and all retired model types.

### Out of scope (BINDING)

- Geofencing, golden hour, Live Activities. That is P3 (and ADR-0007 constrains it).
- Guide export. That is P4.
- Any sync or backend. See [docs/adr/ADR-0005-backend-deferred-cloudkit-first.md](adr/ADR-0005-backend-deferred-cloudkit-first.md).

### Done when

- [ ] A real 2-day, 5-stop plan imports and shows two days, with timeline and map rendering all resolved stops in order.
- [ ] Executing stop 2 does not disturb stop 3 (state isolation across stops verified).
- [ ] Stage goal is visible in field mode, read from the persisted `Stage.goal` — the `stageGoal` stopgap no longer exists.
- [ ] Ideas and script artifacts attach to a trip and persist across relaunch.
- [ ] All P0/P1 tests are green against the document → storage mapper (retargeted to schema v2).
- [ ] `ShootPlan`, `ShootPlanItem`, `ShootLocation`-as-plan-root, and other retired model types no longer exist anywhere in the codebase.

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
