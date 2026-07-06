# Arc

Arc is an iPhone-first capture planning app for solo creators. The app helps a user choose a location, generate a field-ready Capture Plan, work through a focused Shot List, and move finished plans into a Completed archive.

The product name stays **Arc**. The main workflow object is a **Capture Plan**.

## Documentation

Full project documentation lives in [docs/00-index.md](docs/00-index.md). Start there. Key entry points:

- [docs/01-product.md](docs/01-product.md) — what Arc is and why.
- [docs/05-data-model.md](docs/05-data-model.md) — schema v2 + document format.
- [docs/08-roadmap.md](docs/08-roadmap.md) — what to build now.

## Product Direction

Arc is no longer a saved-location catalogue. The redesigned experience is built around execution:

- The root screen is `Capture Plans`, split into `Active` and `Completed`.
- Active plans open directly into the field guide experience.
- Existing Apple Notes-style plans can be pasted into an imported field guide for dogfooding multi-stage execution.
- Planning, location info, context, and editing live in sheets from the field surface.
- Completed plans become read-only summaries with Reopen and Delete actions.
- Pro camera capture is intentionally deferred so the planning loop stays sharp.

## Core Golden Path

1. Open Arc and land on `Capture Plans`.
2. Tap `New Capture Plan`.
3. Choose a location from current GPS, search, or map pin.
4. Choose the content type, capture medium, target platform, style, and timing.
5. Add optional notes.
6. Generate the shot list. Arc fetches context automatically during generation.
7. Review and edit the draft shot list.
8. Tap `Start Capture Plan`.
9. Work the shot list in the field.
10. Complete the plan when all shots are captured.
11. Reopen from Completed if more field work is needed.

## Current Capabilities

- SwiftUI and SwiftData iOS app with iPhone-first navigation.
- Capture Plan root with Active and Completed segments.
- Location picker with GPS default, combined search and map, draggable pin, and manual coordinates.
- Context enrichment using Apple and external data adapters.
- OpenAI-compatible AI service with configurable local or cloud profiles.
- Keychain-backed API key storage.
- Guided new-plan flow with in-memory draft generation and commit-on-approval.
- Imported-plan flow with paste-from-clipboard, local staged parsing, optional AI cleanup, and editable stage/item review.
- Capture brief controls for content type, photo/video/hybrid medium, target platform, style, and timing.
- Content types include Photo Carousel, Short Video, Full Travel Vlog, Travel Story Set, B-Roll Package, Portrait Session, Product Editorial, Documentary Sequence, and Single Hero Shot.
- Style presets include Natural, Cinematic, Minimal, Editorial, Social Reel, and Moody Travel.
- Field-first stage execution with must-capture, optional, voice/sound/transition, before-leaving checks, progress, high-contrast mode, haptics, and completion confirmation.
- Story Safety Net recovery checklist for adding emergency coverage to the current stage.
- Plan editor sheet for brief changes, context refresh, shot edits, and preview-before-replace regeneration.
- Plan info sheet for location, context, and reference cache status.
- Completed plan summary with captured, skipped, and missing sections plus imported-plan story completeness.
- Shareable completed plan editing outlines grouped by stage.
- Optional shot-level image attachment from the photo library. Custom pro camera capture is not part of this core pass.

## Architecture

```text
Arc/
  App/
    ArcApp.swift
    AppContainer.swift
  Core/
    Configuration/
    Networking/
    RateLimiting/
    Security/
    UI/
  Services/
    AI/
    Enrichment/
    Location/
  Features/
    Field/
    Home/
    Locations/
    Planning/
    Settings/
    Shoots/
  Assets.xcassets/
```

Key boundaries:

- `AppContainer` composes live dependencies.
- `Core` holds reusable infrastructure and UI primitives.
- `Services` wraps Apple and external service integrations.
- `Features` owns feature-local UI, view models, and domain types.
- SwiftUI views render and route interaction; view models and services own async work and side effects.

## Data Model

The current persistence model intentionally keeps the existing `Shoot*` type names internally while presenting Capture Plans in the UI.

- `ShootLocation`: persisted location plus optional plan.
- `ShootPlan`: content type, capture medium, target platform, style, timing, notes, raw response, imported source text, story summary, current stage cursor, approval state, and `completedAt`.
- `ShootPlanItem`: ordered field item with title, role, guidance, stage metadata, kind, priority, captured/skipped state, field note, before-leaving flag, and optional attached image data.
- `ShootStatus`: derived status:
  - `draft`: no approved plan.
  - `active`: approved plan with no `completedAt`.
  - `completed`: approved plan with `completedAt`.

For v1, the app queries saved locations normally and splits Active and Completed in memory to avoid fragile SwiftData optional-relationship predicates.

## AI And Context

The planning pipeline is OpenAI-compatible by design:

- Local development can use LM Studio or another OpenAI-compatible local server.
- Cloud profiles can use compatible hosted providers.
- API keys are stored in Keychain.
- Runtime model settings are configured through Settings profiles.
- Generated plans are parsed defensively and only become active after user approval.

Context is fetched automatically when a new shot list is generated. The plan editor also exposes a Context section for manual refresh and inspection before regeneration.

## Privacy And Safety

- No API keys or secrets are committed to source.
- Network requests use the app's typed service layer.
- Location selection is user-driven; no background location tracking is part of this product.
- Cached context and reference data are local app data.
- Pro camera capture, RAW capture, and persistent camera workflows are deferred until explicitly designed.

## Build

Use a temporary DerivedData path to avoid permission issues:

```sh
xcodebuild -scheme Arc -project Arc.xcodeproj -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/ArcDerivedData build
```

## Manual Verification

The manual verification checklist lives in [docs/09-quality.md](docs/09-quality.md).

## Roadmap

The roadmap, current phase, and phase non-goals live in [docs/08-roadmap.md](docs/08-roadmap.md).
