# Arc

Arc is an iPhone-first capture planning app for solo creators. The app helps a user choose a location, generate a field-ready Capture Plan, work through a focused Shot List, and move finished plans into a Completed archive.

The product name stays **Arc**. The main workflow object is a **Capture Plan**.

## Product Direction

Arc is no longer a saved-location catalogue. The redesigned experience is built around execution:

- The root screen is `Capture Plans`, split into `Active` and `Completed`.
- Active plans open directly into the field shot list experience.
- Planning, location info, context, and editing live in sheets from the field surface.
- Completed plans become read-only summaries with Reopen and Delete actions.
- Pro camera capture is intentionally deferred so the planning loop stays sharp.

## Core Golden Path

1. Open Arc and land on `Capture Plans`.
2. Tap `New Capture Plan`.
3. Choose a location from current GPS, search, or map pin.
4. Choose output and timing.
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
- Field-first shot list execution with progress, high-contrast mode, haptics, and completion confirmation.
- Plan editor sheet for regeneration, notes, timing, context refresh, and shot edits.
- Plan info sheet for location, context, and reference cache status.
- Completed plan summary with captured and missing shot sections.
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
- `ShootPlan`: output intent, timing, notes, raw response, approval state, and `completedAt`.
- `ShootPlanItem`: ordered shot list item with title, role, guidance, captured state, and optional attached image data.
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

Run this golden path after UX or persistence changes:

1. Empty launch shows Capture Plans and a New Capture Plan CTA.
2. New Capture Plan uses current GPS by default and still supports search and map pin.
3. Invalid custom timing blocks progress before generation.
4. Generate fetches context and produces a reviewable draft.
5. Start Capture Plan commits the location, plan, and shot list.
6. Field progress updates as items are captured.
7. Capturing the final item shows a completion prompt and does not auto-complete.
8. Complete Plan moves it to Completed.
9. Reopen moves it back to Active.
10. Relaunch preserves Active and Completed state.

## Roadmap

Near-term work should strengthen the core Capture Plan loop:

- Dogfood real plans and score output quality for familiar locations.
- Add style/profile presets for different visual directions.
- Improve reference-image visibility and cache inspection.
- Add export/share for completed plan summaries.
- Add regeneration comparison so users can see what changed.
- Add richer shot-level notes and constraints.

Deferred until the core workflow is proven:

- Pro camera with manual controls, Log, and RAW capture.
- Photo import and automatic matching against the shot list.
- Multi-location shoot days.
- Cloud sync.
- Public launch, monetization, and multi-user collaboration.
