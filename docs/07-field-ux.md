# 07 — Field UX

> **Agent Brief** — Status: Current | Applies to: P0-P3 (specs land in P2-P3) | Owner doc for: field-mode interaction design, stage mantra, done-enough state, Story Safety Net, golden-hour nudge, geofence/Live Activity behavior
> Read [docs/00-index.md](00-index.md) first. Behavioral rules: /AGENTS.md (wins on conduct). Current build phase: see [docs/08-roadmap.md](08-roadmap.md).
> Code pointers verified against ux-redesign @ abce4bc + uncommitted field-guide work (2026-07-06). Re-verify line numbers before editing.

Field mode is the product's moat surface. Data model terms (Stage, CaptureItem, priorities) are defined in [docs/05-data-model.md](05-data-model.md); the story-coverage positioning rationale is in [docs/03-market-research.md](03-market-research.md).

## 1. Binding principles

Every field-mode change must satisfy all five. If a proposed feature violates one, it does not ship in field mode.

| # | Principle | Research rationale | Design implication |
|---|-----------|--------------------|--------------------|
| 1 | **Glanceable, not scrollable** | Creators do not scroll checklists mid-shoot. They memorize 3/5-shot formulas before arriving and glance at checkpoints. Phone friction mid-shoot is intolerable — the camera is in their hand, not the phone. | The primary field surface is one line (the stage mantra, section 2). The full checklist is a drill-down, never the default. Any interaction on the primary surface is one tap. No feature may require reading more than one line to act. |
| 2 | **Story is safe / done enough** | ~52% of creators report burnout; experienced travel creators deliberately under-film to stay present. Completion guilt ("87% done") is a churn risk for a solo owner-user. | Arc has an explicit "done enough" state (section 3) that is celebrated and invites stopping. Never render a shame-inducing completion percentage as the headline metric. Skipping is a first-class resolution, visually neutral, never red. |
| 3 | **Safety net, not script** | Improvisation is identity for run-and-gun creators. A tool that reads as a script to obey gets abandoned; a tool that catches what memory drops gets kept. | Off-plan captures (`CaptureItem.origin == .fieldAdded`) are celebrated, not flagged as deviations. The Story Safety Net (section 4) is framed as a memory prosthetic. Arc never says "you missed" — it says "still available to grab." |
| 4 | **Offline-first + battery-light** | Field reality: remote locations, dead zones, roaming data off, all-day shoots on one battery shared with the camera roll. | The core loop (view stage, capture/skip/note/photo, advance, safety net, done-enough) must work with zero connectivity. Network features (enrichment, weather, golden hour) are additive and fail silently. Battery-light is an acceptance criterion (section 6), not an aspiration. |
| 5 | **Outdoor readability** | Field screens are read in direct sunlight, often with polarized sunglasses. | The existing high-contrast mode is mandatory support for every field screen, driven by `@AppStorage("Arc.FieldHighContrastMode")` (FieldView.swift:15, toolbar toggle at :157). New field UI must implement both palettes; high-contrast means solid backgrounds, heavier weights, larger type — see the `isHighContrast` branches throughout FieldView.swift. |

## 2. Stage mantra spec

The stage mantra is the primary field surface. Everything else in field mode is secondary.

- **Content**: one glanceable line = `Stage.goal` + musts remaining in that stage. Example: **"Arrival texture — 2 musts left."**
- **Composition rule**: goal text verbatim from `Stage.goal`; count = unresolved `CaptureItem`s in the stage with must priority. When the count reaches 0 the suffix becomes "musts done" (stage-scope safety, distinct from plan-scope "story is safe").
- **One-tap confirm**: tapping the mantra's confirm affordance marks the next unresolved must in the stage as captured. No list navigation required for the happy path.
- **Drill-down**: the full per-stage checklist (today's `FieldView` item rows) is one tap below the mantra and is the *secondary* surface. Notes, photos, skips, and field-added items live there.
- **Everywhere the stage is summarized** (field screen header, Live Activity, lock screen — section 6), the mantra format is the same string. One format, memorized once.
- **Blocking dependency**: `Stage.goal` requires schema v2 ([ADR-0002](adr/ADR-0002-schema-v2-rebuild.md)). Today the goal is captured in `FieldGuideStageDraft` during import but **dropped at commit** — the item loop at ImportPlanFlowView.swift:327-350 never writes it and `ShootPlanItem` has no goal field. Do not build the mantra on the v1 model; fix the model first.

## 3. Done-enough spec ("story is safe")

- **Trigger**: fires when all must-priority items **and** all before-leaving items in scope are resolved (captured or skipped). Scope is the active stage for the stage-level variant and the whole plan for the plan-level variant. Skipped counts as resolved — a deliberate skip is a coverage decision, not a failure.
- **Copy**: celebratory and explicitly permission-granting. Pattern: **"Story is safe — go enjoy."** Variants may name what is optional ("3 nice-to-haves left, all optional"). Never "X% complete," never "still missing."
- **Visual**: a distinct calm/celebratory state (not the same treatment as 100% completion). "Story is safe" and "everything captured" are two different states; the first must feel like a finish line, the second like a bonus.
- **Behavior**: reaching story-is-safe never auto-advances, never nags, and suppresses further must-related nudges (including golden-hour, section 5) for that scope. The user can keep capturing; new `fieldAdded` items do not revoke the state unless they are marked must.
- **Relation to plan completion**: completing the plan remains an explicit user action with confirmation (FieldView.swift:253). Story-is-safe is a state, not a transition.

## 4. Story Safety Net spec

The universal fallback vocabulary — the minimum coverage that makes any location editable into a story:

| Slot | Kind | Priority | Current hardcoded draft (FieldView.swift:539-546) |
|------|------|----------|---------------------------------------------------|
| Wide establishing | shot | must | "Wide shot of where you are" — hold 8-10 s |
| Detail close-up | shot | must | "Close-up of one useful detail" |
| Human action | shot | optional | "Hands or feet doing something" |
| Natural sound | sound | must | "Natural sound" — 10 s, no talking |
| Honest reaction voice line | voice | must | "Honest reaction" — one line on what changed/surprised/mattered |
| Leaving transition | transition | must, before-leaving | "Leaving shot" |

Target behavior (schema v2):

- Safety net items are injected as a **Stage of kind `safetyNet`** with `CaptureItem.origin == .safetyNet`, not appended into the current stage.
- **Dedup by design**: a plan/stop has at most one safety-net stage; a second tap targets the existing stage (re-surfaces it, resets nothing). This structurally fixes the current defect — `addSafetyNetItems()` at FieldView.swift:533-568 appends the 6 items to the current stage with no dedup, so repeated taps insert duplicates.
- **Framing**: memory prosthetic, never guilt. Offer copy in the spirit of "grab the basics before you go" — never "you haven't captured enough." The safety net is also the T0 import fallback vocabulary (see [docs/06-import-spec.md](06-import-spec.md)); the two must stay one list.

## 5. Golden-hour nudge spec

- **Inputs**: `SunMoonCalculator` (Arc/Services/Enrichment) for golden-hour windows at the stop coordinates and date; Open-Meteo (`OpenMeteoAPIClient`) or WeatherKit for cloud-cover sanity. All inputs are best-effort; no connectivity → no nudge, no error.
- **Trigger**: the upcoming/active golden-hour window overlaps time-plausible remaining musts at the **active stop** only. Suppressed once story-is-safe fires for that stop (section 3).
- **Copy pattern**: **"Golden light 20 min — 2 must-captures left."** One line, mantra-shaped, one tap opens the active stage.
- **Rate limit**: at most one nudge per golden-hour window per stop.
- **Boundary**: Arc *consumes* light data; it is never a sun-planning tool. No sun-path visualizations, no azimuth charts, no shot-planning-by-ephemeris — PhotoPills exists and owns that. If a feature request reads like sun planning, it is out of scope.

## 6. Geofence + Live Activity spec

Governed by [ADR-0007](adr/ADR-0007-while-in-use-location-surfacing.md), the scoped amendment to AGENTS.md:22 (which otherwise bans background execution/location).

- **Authorization**: while-in-use only. Never request Always. Never prompt at app launch — request in context, when the user enables arrival surfacing.
- **Arrival behavior**: arriving inside a stop's region surfaces that stop's first stage (foreground: navigates/highlights; via Live Activity otherwise). Surfacing only — no auto-capture, no auto-advance.
- **Live Activity / lock screen**: shows the stage mantra + must count in the section 2 format; updates on stage advance and on must-count change. The lock screen is the ideal glanceable surface — the phone never needs unlocking to check the checkpoint.
- **Graceful degradation**: permission denied or restricted → manual stop switching stays primary (it is primary regardless); no nag, one settings-deeplink hint at most. Every field feature works fully without location.
- **Battery-light is an acceptance criterion**: region monitoring over continuous location updates; no periodic polling; measurable target — a full field day with Arc active must not be materially worse than Arc backgrounded. If it can't be met, ship without geofencing.
- **Privacy**: no location logging, no location analytics, no location persisted beyond what the plan already stores (stop coordinates). Location is consumed transiently for surfacing only.

## 7. Interaction inventory (current build)

Verified against FieldView.swift on ux-redesign @ abce4bc + uncommitted work. Preserve these behaviors through the schema v2 rebuild unless a spec above changes them.

| Interaction | Behavior | Pointer |
|-------------|----------|---------|
| Capture / skip | Mutually exclusive toggles: capturing clears skipped and vice versa; haptic feedback on both | FieldView.swift:389-405 |
| Field note | Per-item note editor sheet writes `ShootPlanItem.fieldNote`; non-empty notes render inline on the item row | FieldView.swift:248-251, 920-921, 1196 |
| Photo attach | PhotosPicker per item; image resized to 1600 px max side, JPEG 0.76; attaching marks the item captured and clears skipped | FieldView.swift:489-508, 574-591 |
| Before-leave gate | Advancing with unresolved before-leaving items opens a confirm dialog listing the blockers by title; "Move Anyway" overrides | FieldView.swift:263-273, 377, 447-458 |
| Plan completion | Explicit "Complete this plan?" confirmation; sets `completedAt`, dismisses to review | FieldView.swift:253-262, 471-480 |
| Safety net | Sheet appends 6 hardcoded items to the current stage — **no dedup; duplicate-insertion defect**; replaced by section 4 spec | FieldView.swift:246, 533-568 |
| High-contrast toggle | Toolbar sun button + settings toggle flip `Arc.FieldHighContrastMode`; propagated as `isHighContrast` to all field components | FieldView.swift:15, 157-163, 200 |
| Stage navigation | Previous/next stage against computed `fieldStages` (grouped on `stageOrderIndex`/`stageTitle` — ShootPlan.swift:104) | FieldView.swift:437-469 |

Known gaps in the current build (do not treat as intended behavior): cached Flickr reference images (`DiskReferenceImageCache`) are never displayed in any view; stage goal is absent from the persisted model (section 2); there is no done-enough state, no mantra surface, no golden-hour nudge, and no location surfacing yet — those are P2-P3 work per [docs/08-roadmap.md](08-roadmap.md).
