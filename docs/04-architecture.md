# 04 — Architecture

> **Agent Brief** — Status: Current | Applies to: All phases | Owner doc for: codebase layer map, DI, plan-creation flows, target module additions, known-debt register, platform sketch
> Read [docs/00-index.md](00-index.md) first. Behavioral rules: /AGENTS.md (wins on conduct). Current build phase: see [docs/08-roadmap.md](08-roadmap.md).
> Code pointers verified against `task-owner-mvp-through-p4` after schema-v2 implementation (2026-07-07). Re-verify line numbers before editing.

Companion docs: data shapes in [docs/05-data-model.md](05-data-model.md), import behavior in [docs/06-import-spec.md](06-import-spec.md), field UX in [docs/07-field-ux.md](07-field-ux.md), phase gating in [docs/08-roadmap.md](08-roadmap.md) and [docs/02-business.md](02-business.md).

---

## 1. Current architecture

Single iOS app target. SwiftUI + SwiftData, iOS 26. `ArcTests` exists for parser/codec/mapper coverage. No backend. All persistence and AI calls run on-device or direct-to-provider from the phone.

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
| Features / Planning | `Arc/Features/Planning/` | Domain: import/parsing/planning value types and generators: `FieldGuide.swift`, `ImportedPlanParser.swift`, `ImportedPlanGenerator.swift`, `ShotListGenerator.swift`, `ShotPlanParser.swift`, `PlanningOptions.swift`. No SwiftData models live here now. |
| Features / Trips | `Arc/Features/Trips/` | Domain: schema-v2 SwiftData model and document mapper: `Trip`, `TripArtifact`, `ShootDay`, `Stop`, `Stage`, `CaptureItem`, `TripDocumentMapper`. |
| Features / Field | `Arc/Features/Field/Presentation/` | `FieldView.swift` (stage-by-stage execution) |
| Features / Shoots | `Arc/Features/Shoots/` | Domain: `ShootDraftItem.swift`. Presentation: `NewShootFlowView.swift`, `ImportPlanFlowView.swift`, `CompletedShootView.swift`, `PlanEditorSheet.swift`, `ShootInfoSheet.swift`, `ShootPlanningComponents.swift`, `ShootsView.swift` |
| Features / Locations | `Arc/Features/Locations/` | Domain: `LocationContextBundle.swift`. Presentation: `AddLocationView.swift`, `LocationContextView.swift`, `ShootSpotPickerView.swift`. ViewModels: `LocationContextViewModel.swift`, `LocationEditorViewModel.swift`; these now edit/enrich `Stop`. |
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

Registered in `ArcApp.swift`:

```swift
.modelContainer(for: [Trip.self, TripArtifact.self, ShootDay.self, Stop.self, Stage.self, CaptureItem.self, LLMProfile.self])
```

| @Model | File | Notes |
|---|---|---|
| `Trip` | `Arc/Features/Trips/Domain/TripModels.swift` | Root entity; owns days and artifacts |
| `TripArtifact` | `Arc/Features/Trips/Domain/TripModels.swift` | `ideas`, `shootList`, or generated `script` body |
| `ShootDay` | `Arc/Features/Trips/Domain/TripModels.swift` | Owns ordered stops |
| `Stop` | `Arc/Features/Trips/Domain/TripModels.swift` | Physical place; optional coordinates; source geo anchor; enrichment cache |
| `Stage` | `Arc/Features/Trips/Domain/TripModels.swift` | Ordered execution unit with persisted `goal` and `kind` |
| `CaptureItem` | `Arc/Features/Trips/Domain/TripModels.swift` | Capturable item with provenance and optional photo |
| `LLMProfile` | `Arc/Features/Settings/Domain/LLMProfile.swift` | Cloud AI provider/profile settings |

The old `ShootLocation` / `ShootPlan` / `ShootPlanItem` graph is deleted. See [docs/05-data-model.md](05-data-model.md), [docs/adr/ADR-0002-schema-v2-rebuild.md](adr/ADR-0002-schema-v2-rebuild.md), and [docs/adr/ADR-0003-store-reset-pre-ship.md](adr/ADR-0003-store-reset-pre-ship.md).

### 1.4 Plan creation flow (a): location-generated

Entry: `NewShootFlowView.swift` (Shoots feature).

1. User picks/creates a `Stop` draft location (location pick step; `ShootSpotPickerView` / `AddLocationView`).
2. User fills the brief (output intent, capture medium, target platform, style preset, shoot window — `PlanningOptions`).
3. `generateDraft()` calls `locationEnricher.enrich(...)` — `LocationEnricher` fans out to Overpass (POIs), Wikipedia (summary), Flickr (reference images → `DiskReferenceImageCache`), Open-Meteo (weather), `SunMoonCalculator` (golden hour); result JSON is stored on the stop (`enrichmentJSON`, `lastEnrichedAt`).
4. `ShotListGenerator` (constructed in the view with `aiService` from `makeAIService`) builds the prompt from brief + enrichment context and calls `AIServicing` (`OpenAICompatibleAIService`, rate-limited).
5. `ShotPlanParser` parses the raw model response into `PlannedShotDraft` values.
6. User reviews/edits draft items, then commit inserts a one-day, one-stop `Trip` graph and saves.

### 1.5 Plan creation flow (b): imported / `.arcguide`

Entry: `ImportPlanFlowView.swift` (Shoots feature).

1. User pastes plan text, receives shared text/file handoff, or opens a `.arcguide`.
2. Text import runs `ImportedPlanParser` (T0) and optional smart tiers to produce an `ArcPlanDocument`; structured `.arcguide` files decode through `ArcDocumentCodec.decodePlanOrGuide` and skip parsing.
3. User edits the draft surface.
4. Commit maps `ArcPlanDocument` directly into `Trip -> ShootDay -> Stop -> Stage -> CaptureItem` through `TripDocumentMapper` and saves.
5. Original source text is stored as a `TripArtifact(kind: shootList)`; generated review output later writes `TripArtifact(kind: script)`.

The full T0–T3 tier ladder (heuristics → on-device Foundation Models → optional cloud → Private Cloud Compute) is specified in [docs/06-import-spec.md](06-import-spec.md).

### 1.6 Field execution and review

- **Field execution** — `Arc/Features/Field/Presentation/FieldView.swift`: renders the active `Trip`, trip timeline, map, current stop/stage, stage mantra, and capture/skip/note/photo actions. Safety Net inserts one `Stage(kind: safetyNet)` per stop with `CaptureItem.origin == .safetyNet`.
- **Review** — `Arc/Features/Shoots/Presentation/CompletedShootView.swift`: segmented post-shoot review of execution data; completion generates a script artifact and review shares markdown plus `.arcguide`.

---

## 2. Target additions by phase

Phases and gates are defined in [docs/08-roadmap.md](08-roadmap.md); gate criteria live only in [docs/02-business.md](02-business.md). Do not build ahead of the current phase.

| Phase | New modules / targets |
|---|---|
| P0 Stabilize | Done on main: test target, parser baseline, document safety fixes. |
| P1 Import pipeline v2 + document format | Done on main: `Arc/Core/Documents/`, T0 document parser, Foundation Models service, App Intent/handoff surfaces. |
| P2 Schema v2 + timeline and map | Implemented on owner-test branch: `Arc/Features/Trips/` domain, trip timeline, map, direct document mapper, retired model deletion. |
| P3 Field ergonomics v2 + review/export v2 | Live Activity extension (stage mantra on Lock Screen / Dynamic Island). While-in-use geofence service (scoped per [docs/adr/ADR-0007-while-in-use-location-surfacing.md](adr/ADR-0007-while-in-use-location-surfacing.md); AGENTS.md:30 amendment). Golden-hour nudge logic reusing `SunMoonCalculator`. |
| P4 Guide export + share preview + email capture | `.arcguide` guide export from executed trips; off-app static preview page + email capture (see [docs/02-business.md](02-business.md) and [docs/adr/ADR-0006-email-capture-and-paid-guides.md](adr/ADR-0006-email-capture-and-paid-guides.md)). |
| P5 Platform | Architecture only — see section 4. Gated on G3 + G4. |

---

## 3. Known-debt register

| Item | Evidence pointer | Retiring phase |
|---|---|---|
| Flickr reference images cached to disk but never displayed in any view | `Arc/Services/Enrichment/ReferenceImageCache.swift` (`DiskReferenceImageCache`), wired in `AppContainer.swift:39`; no consuming view | P3 — surface in field/review UI or retire the pipeline |
| Off-app guide preview/email capture not built | Local `.arcguide` export/import exists; no web preview or ESP gate | P4 after G2 |
| Golden-hour nudges not built | `SunMoonCalculator` exists; field UI does not surface nudges | P3 after G1 |
| While-in-use stop surfacing / Live Activity not built | ADR-0007 defines constraints; no implementation yet | P3 after G1 |
| Reference-image cache has no TTL or size limit | `DiskReferenceImageCache` in `ReferenceImageCache.swift` | Backlog |

---

## 4. Platform (P5) sketch

**Architecture only — do not build until G3 + G4 (see [docs/02-business.md](02-business.md)).** No off-app infrastructure exists today, and none is required through P3 ([docs/adr/ADR-0005-backend-deferred-cloudkit-first.md](adr/ADR-0005-backend-deferred-cloudkit-first.md)).

- **CloudKit-first candidate.** Private database for owner sync/backup of trips; `CKShare` / public database for shared guide previews. Zero server ops, native auth, free at this scale — right shape for a solo owner whose product is on-device. Weakness: web-side buyers and payments are awkward.
- **Thin custom API counterweight.** Only if paid guides (G4, [docs/adr/ADR-0006-email-capture-and-paid-guides.md](adr/ADR-0006-email-capture-and-paid-guides.md)) demand web checkout/delivery to non-iOS buyers: a minimal endpoint set (guide fetch, purchase webhook, email capture) fronting `.arcguide` payloads. Never a sync engine; the app must keep working fully offline with the backend down.
- **On-device forever by default:** captured photos and field notes/execution data never leave the device unless the owner explicitly exports or shares. Guide exports are deliberate artifacts (`.arcguide` / preview page), not ambient sync.
- **Interchange stays the boundary.** Everything the platform serves derives from `ArcPlanDocument` / `ArcGuideDocument` ([docs/adr/ADR-0004-arcguide-document-interchange.md](adr/ADR-0004-arcguide-document-interchange.md)); `Arc/Core/Documents/` remains SwiftData-free so codecs can be reused server-side or in extensions unchanged.
