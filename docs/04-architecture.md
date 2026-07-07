# 04 — Architecture

> **Agent Brief** — Status: Current | Applies to: All phases | Owner doc for: codebase layer map, DI, plan-creation flows, target module additions, known-debt register, platform sketch
> Read [docs/00-index.md](00-index.md) first. Behavioral rules: /AGENTS.md (wins on conduct). Current build phase: see [docs/08-roadmap.md](08-roadmap.md).
> Code pointers verified against ux-redesign @ abce4bc + uncommitted field-guide/docs-alignment work (2026-07-06). Re-verify line numbers before editing.

Companion docs: data shapes in [docs/05-data-model.md](05-data-model.md), import behavior in [docs/06-import-spec.md](06-import-spec.md), field UX in [docs/07-field-ux.md](07-field-ux.md), phase gating in [docs/08-roadmap.md](08-roadmap.md) and [docs/02-business.md](02-business.md).

---

## 1. Current architecture

Single iOS app target. SwiftUI + SwiftData, iOS 26. No test target, no extensions, no backend. All persistence and AI calls run on-device or direct-to-provider from the phone.

### 1.1 Layer map

| Layer | Path | Contents |
|---|---|---|
| App | `Arc/App/` | `ArcApp.swift` (entry point, SwiftData model container, roots `HomeView`), `AppContainer.swift` (manual DI struct) |
| Core / Configuration | `Arc/Core/Configuration/` | `AIConfiguration.swift` (bundle-loaded defaults, resolved against an optional `LLMProfile`) |
| Core / Networking | `Arc/Core/Networking/` | `HTTPClient.swift` (`URLSessionHTTPClient`), `NetworkError.swift` |
| Core / RateLimiting | `Arc/Core/RateLimiting/` | `FixedWindowRateLimiter.swift` (per-minute request cap for AI calls) |
| Core / Security | `Arc/Core/Security/` | `KeychainStore.swift` (implements `APIKeyProviding`) |
| Core / UI | `Arc/Core/UI/` | `AppVisualStyle.swift` (palette, shared styling incl. `ArcPalette.tint`) |
| Services / AI | `Arc/Services/AI/` | `AIService.swift` (`AIServicing` protocol), `OpenAICompatibleAIService.swift` (T2 cloud path), `AIModels.swift` |
| Services / Enrichment | `Arc/Services/Enrichment/` | `LocationEnricher.swift` (facade), `OverpassAPIClient.swift`, `WikipediaAPIClient.swift`, `FlickrAPIClient.swift`, `ReferenceImageCache.swift` (`DiskReferenceImageCache`), `OpenMeteoAPIClient.swift`, `SunMoonCalculator.swift` |
| Services / Location | `Arc/Services/Location/` | `LocationInputServices.swift` (location pick / editor service factory) |
| Features / Planning | `Arc/Features/Planning/` | Domain: `ShootPlan.swift` (`ShootPlan`, `ShootPlanItem` @Models), `FieldGuide.swift` (draft structs, uncommitted), `ImportedPlanParser.swift` (uncommitted), `ImportedPlanGenerator.swift` (uncommitted), `ShotListGenerator.swift`, `ShotPlanParser.swift`, `PlanningOptions.swift`. ViewModels: `PlanViewModel.swift`. Presentation: empty |
| Features / Field | `Arc/Features/Field/Presentation/` | `FieldView.swift` (stage-by-stage execution) |
| Features / Shoots | `Arc/Features/Shoots/` | Domain: `ShootDraftItem.swift`. Presentation: `NewShootFlowView.swift`, `ImportPlanFlowView.swift` (uncommitted), `CompletedShootView.swift`, `PlanEditorSheet.swift`, `ShootInfoSheet.swift`, `ShootPlanningComponents.swift`, `ShootsView.swift` |
| Features / Locations | `Arc/Features/Locations/` | Domain: `ShootLocation.swift` (@Model), `LocationContextBundle.swift`. Presentation: `AddLocationView.swift`, `LocationContextView.swift`, `ShootSpotPickerView.swift`. ViewModels: `LocationContextViewModel.swift`, `LocationEditorViewModel.swift` |
| Features / Settings | `Arc/Features/Settings/` | Domain: `LLMProfile.swift` (@Model). Presentation: `SettingsView.swift` |
| Features / Home | `Arc/Features/Home/Presentation/` | `HomeView.swift` (root tab/navigation shell; receives all DI dependencies) |
| Features / Review | `Arc/Features/Review/` | Empty `Presentation/` folder — review currently lives in `CompletedShootView.swift` under Shoots |

### 1.2 Dependency injection

`AppContainer` (`Arc/App/AppContainer.swift`) is a plain struct built once as `AppContainer.live` and held by `ArcApp`. No third-party DI. It wires:

- `defaultAIConfiguration` — `AIConfiguration.fromBundle()`
- `makeAIService: (LLMProfile?) -> any AIServicing` — factory closure; resolves configuration per profile and builds an `OpenAICompatibleAIService` with a shared `URLSessionHTTPClient`, the `KeychainStore` as key provider, and a fresh `FixedWindowRateLimiter` (requests-per-minute over a 60 s window)
- `apiKeyStore` — `KeychainStore` (`APIKeyProviding`)
- `locationEnricher` — `LocationEnricher` composing Overpass + Wikipedia + Flickr + Open-Meteo clients and `SunMoonCalculator`
- `referenceImageCache` — `DiskReferenceImageCache`
- `locationEditorServices` — `LocationEditorServiceFactory.live`

`ArcApp` passes every dependency into `HomeView` as init parameters; views thread them downward manually. There is no environment-based service locator. New services (e.g. the T1 `FoundationModelsPlanService` in P1) must be added to `AppContainer` and threaded the same way until a deliberate refactor says otherwise.

### 1.3 SwiftData model container

Registered in `ArcApp.swift:20`:

```swift
.modelContainer(for: [ShootLocation.self, ShootPlan.self, ShootPlanItem.self, LLMProfile.self])
```

| @Model | File | Notes |
|---|---|---|
| `ShootLocation` | `Arc/Features/Locations/Domain/ShootLocation.swift` | One plan per location; plans are only reachable through their location |
| `ShootPlan` | `Arc/Features/Planning/Domain/ShootPlan.swift` | Cascade-deletes `items`; stages are computed, not stored (see 1.6) |
| `ShootPlanItem` | `Arc/Features/Planning/Domain/ShootPlan.swift` | Carries `stageTitle` + `stageOrderIndex` strings/ints for grouping; `role` string plus `kindRawValue` |
| `LLMProfile` | `Arc/Features/Settings/Domain/LLMProfile.swift` | Cloud AI provider/profile settings |

Schema v2 (Trip / TripArtifact / ShootDay / Stop / Stage / CaptureItem) replaces this container in P2 via destructive store reset — see [docs/05-data-model.md](05-data-model.md), [docs/adr/ADR-0002-schema-v2-rebuild.md](adr/ADR-0002-schema-v2-rebuild.md), [docs/adr/ADR-0003-store-reset-pre-ship.md](adr/ADR-0003-store-reset-pre-ship.md).

### 1.4 Plan creation flow (a): location-generated

Entry: `NewShootFlowView.swift` (Shoots feature).

1. User picks/creates a `ShootLocation` (location pick step; `ShootSpotPickerView` / `AddLocationView`).
2. User fills the brief (output intent, capture medium, target platform, style preset, shoot window — `PlanningOptions`).
3. `generateDraft()` calls `locationEnricher.enrich(...)` — `LocationEnricher` fans out to Overpass (POIs), Wikipedia (summary), Flickr (reference images → `DiskReferenceImageCache`), Open-Meteo (weather), `SunMoonCalculator` (golden hour); result JSON is stored on the location (`enrichmentJSON`, `lastEnrichedAt`).
4. `ShotListGenerator` (constructed in the view with `aiService` from `makeAIService`) builds the prompt from brief + enrichment context and calls `AIServicing` (`OpenAICompatibleAIService`, rate-limited).
5. `ShotPlanParser` parses the raw model response into `PlannedShotDraft` values.
6. User reviews/edits draft items, then commit inserts `ShootPlan` + `ShootPlanItem`s attached to the location and saves.

### 1.5 Plan creation flow (b): imported (uncommitted, being formalized in P1)

Entry: `ImportPlanFlowView.swift` (Shoots feature).

1. User pastes plan text (Apple Notes / ChatGPT markdown).
2. `ImportedPlanParser` (T0 heuristic) parses it into a staged `FieldGuideDraft` (`FieldGuideStageDraft` with `goal`, `FieldGuideItemDraft`s).
3. Optionally, `ImportedPlanGenerator` (T2 cloud) sends the text through `AIServicing` for cleanup → JSON → draft; on failure it falls back to the T0 parser.
4. User edits the draft (stage titles, goals, items, priorities).
5. Commit (`ImportPlanFlowView.swift:480-555`) requires a picked real location (guard at `:481`) and builds the `ShootLocation` from the picked coordinates (`:495-499`), then creates a `ShootPlan` with `source: .importedText` and flattened `ShootPlanItem`s; the item loop (`:522-545`) writes the stage `goal` edited in step 4 into the transitional `stageGoal` field (`:535`). Both P0 stopgaps (required location pick; transitional `stageGoal`) are implemented. P2 fixes both structurally with `Stage.goal` and optional `Stop` coordinates — see [docs/08-roadmap.md](08-roadmap.md), [docs/05-data-model.md](05-data-model.md), and [docs/06-import-spec.md](06-import-spec.md).

The full T0–T3 tier ladder (heuristics → on-device Foundation Models → optional cloud → Private Cloud Compute) is specified in [docs/06-import-spec.md](06-import-spec.md).

### 1.6 Field execution and review

- **Field execution** — `Arc/Features/Field/Presentation/FieldView.swift`: renders `plan.fieldStages` (computed grouping at `ShootPlan.swift:104`) one stage at a time with capture/skip/note/photo actions; `addSafetyNetItems()` at `FieldView.swift:533-577` appends the 6 hardcoded Story Safety Net items, skipping titles already unresolved in the current stage (P0 dedup guard at `:548-555`; structural fix specified in [docs/07-field-ux.md](07-field-ux.md)).
- **Review** — `Arc/Features/Shoots/Presentation/CompletedShootView.swift`: segmented post-shoot review of execution data; export today is a plain-text `ShareLink` only (replaced by review/export v2 in P3 and `.arcguide` export in P4 — [docs/adr/ADR-0004-arcguide-document-interchange.md](adr/ADR-0004-arcguide-document-interchange.md)).

---

## 2. Target additions by phase

Phases and gates are defined in [docs/08-roadmap.md](08-roadmap.md); gate criteria live only in [docs/02-business.md](02-business.md). Do not build ahead of the current phase.

| Phase | New modules / targets |
|---|---|
| P0 Stabilize | Unit test target (first tests: parsers, `fieldStages` grouping, safety-net dedup). No new app modules. |
| P1 Import pipeline v2 + document format | `Arc/Core/Documents/` — `ArcPlanDocument` / `ArcGuideDocument` codecs (one JSON schema, `kind` plan \| guide, integer `schemaVersion`, UTType `com.arc.guide`, `.arcguide`; folder must never import SwiftData). `Arc/Services/AI/FoundationModelsPlanService.swift` — T1 on-device `@Generable` service, availability-gated via `SystemLanguageModel`, per-day chunking, prewarm on import screen, guardrail fallback to T0. Share extension target + App Group (receive text/files into the import flow). App Intents: `ImportPlanIntent`. |
| P2 Schema v2 + timeline and map | `Arc/Features/Trips/` — Domain (Trip, TripArtifact, ShootDay, Stop, Stage, CaptureItem per [docs/05-data-model.md](05-data-model.md)) + Presentation (trip timeline, map from geo anchors). Store reset per [docs/adr/ADR-0003-store-reset-pre-ship.md](adr/ADR-0003-store-reset-pre-ship.md). |
| P3 Field ergonomics v2 + review/export v2 | Live Activity extension (stage mantra on Lock Screen / Dynamic Island). While-in-use geofence service (scoped per [docs/adr/ADR-0007-while-in-use-location-surfacing.md](adr/ADR-0007-while-in-use-location-surfacing.md); AGENTS.md:30 amendment). Golden-hour nudge logic reusing `SunMoonCalculator`. |
| P4 Guide export + share preview + email capture | `.arcguide` guide export from executed trips; off-app static preview page + email capture (see [docs/02-business.md](02-business.md) and [docs/adr/ADR-0006-email-capture-and-paid-guides.md](adr/ADR-0006-email-capture-and-paid-guides.md)). |
| P5 Platform | Architecture only — see section 4. Gated on G3 + G4. |

---

## 3. Known-debt register

| Item | Evidence pointer | Retiring phase |
|---|---|---|
| Flickr reference images cached to disk but never displayed in any view | `Arc/Services/Enrichment/ReferenceImageCache.swift` (`DiskReferenceImageCache`), wired in `AppContainer.swift:39`; no consuming view | P3 — surface in field/review UI or retire the pipeline |
| Plans reachable only via their `ShootLocation` (one-plan-per-location shape) | `ShootLocation.swift`; import commit now requires a picked real location (`ImportPlanFlowView.swift:495-499`) | P2 replaces location-as-root with Trip/Stop |
| Stages computed by grouping items on `(stageOrderIndex, stageTitle)` on hot UI paths | `ShootPlan.swift:104` (`fieldStages`); re-evaluated per render in `FieldView` | P2 — Stage becomes a stored entity |
| Stage `goal` denormalized per item as the transitional `stageGoal` stopgap (P0 implemented) | `ShootPlan.swift:173`; written in the commit item loop at `ImportPlanFlowView.swift:522-545` (`:535`) | P2 replaces with `Stage.goal` |
| `ShootPlanItem.role` string redundant with `kind` | `ShootPlan.swift:168` (`role`) vs `:221` (`kind` from `kindRawValue`) | P2 — drop `role`, keep `CaptureItem` kind |
| Hardcoded safety-net items (P0 dedup guard implemented — unresolved-title skip at `FieldView.swift:548-555`) | `FieldView.swift:533-577` (`addSafetyNetItems()`) | P0 guard done; P3 proper Safety Net mechanics |
| No test target | Repo has no test targets or CI | P0 |
| Raw-value enum fallback defaults mask data issues (bad stored strings silently become `.natural`, `.now`, `.shot`, …) | e.g. `ShootPlan.swift:92-98`, `:221-223` | P2 note — schema v2 must fail loudly or migrate explicitly |
| Reference-image cache has no TTL or size limit | `DiskReferenceImageCache` in `ReferenceImageCache.swift` | Backlog |

---

## 4. Platform (P5) sketch

**Architecture only — do not build until G3 + G4 (see [docs/02-business.md](02-business.md)).** No off-app infrastructure exists today, and none is required through P3 ([docs/adr/ADR-0005-backend-deferred-cloudkit-first.md](adr/ADR-0005-backend-deferred-cloudkit-first.md)).

- **CloudKit-first candidate.** Private database for owner sync/backup of trips; `CKShare` / public database for shared guide previews. Zero server ops, native auth, free at this scale — right shape for a solo owner whose product is on-device. Weakness: web-side buyers and payments are awkward.
- **Thin custom API counterweight.** Only if paid guides (G4, [docs/adr/ADR-0006-email-capture-and-paid-guides.md](adr/ADR-0006-email-capture-and-paid-guides.md)) demand web checkout/delivery to non-iOS buyers: a minimal endpoint set (guide fetch, purchase webhook, email capture) fronting `.arcguide` payloads. Never a sync engine; the app must keep working fully offline with the backend down.
- **On-device forever by default:** captured photos and field notes/execution data never leave the device unless the owner explicitly exports or shares. Guide exports are deliberate artifacts (`.arcguide` / preview page), not ambient sync.
- **Interchange stays the boundary.** Everything the platform serves derives from `ArcPlanDocument` / `ArcGuideDocument` ([docs/adr/ADR-0004-arcguide-document-interchange.md](adr/ADR-0004-arcguide-document-interchange.md)); `Arc/Core/Documents/` remains SwiftData-free so codecs can be reused server-side or in extensions unchanged.
