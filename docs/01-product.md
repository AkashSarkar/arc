# 01 — Product: Vision, Workflow, Loop, Principles

> **Agent Brief** — Status: Current | Applies to: All phases | Owner doc for: product vision, owner workflow, core loop, positioning conclusions, product principles, non-goals, dogfood success metrics
> Read [docs/00-index.md](00-index.md) first. Behavioral rules: /AGENTS.md (wins on conduct). Current build phase: see [docs/08-roadmap.md](08-roadmap.md).
> Code pointers verified against `task-owner-mvp-through-p4` after owner-test MVP implementation (2026-07-07). Re-verify line numbers before editing.

## 1. Vision

Arc is a field companion that turns intent into coverage. Its job is not to be smarter than the creator — the creator already knows the story. Its job is to keep them from forgetting story-critical shots while moving through a real place under time, weather, energy, and attention constraints. Everything Arc does serves one moment: standing at a stop, about to leave, and knowing with certainty that the story is safe. Long-term, the same execution data makes Arc the execution + provenance layer of the travel-guide economy: guides auto-drafted from trips that were actually walked, shot, and verified in the field ([ADR-0004](adr/ADR-0004-arcguide-document-interchange.md)).

## 2. The owner and the three-artifact workflow

The owner is a solo travel content creator (also the sole developer). Every trip produces exactly three artifacts. Arc's job is to ingest the first two and generate the third.

| Artifact | Where it lives today | Arc responsibility now | Arc responsibility later |
|---|---|---|---|
| **IDEAS** (pre-trip: story, titles, thumbnail concepts) | Apple Notes freeform + ChatGPT-generated markdown | Ingest via paste (import pipeline, [docs/06-import-spec.md](06-import-spec.md)); store as `TripArtifact(kind: ideas)` in schema v2 | Inform stage goals and Must tiers; surface title/thumbnail concepts during review |
| **SHOOT LIST** (followed in the field) | Same sources; sometimes printed or memorized | Parse into a staged field guide (Stages, CaptureItems, Must tiers); execute in field mode ([docs/07-field-ux.md](07-field-ux.md)) | Multi-stop day timeline + map; location-aware surfacing ([ADR-0007](adr/ADR-0007-while-in-use-location-surfacing.md)) |
| **SCRIPT** (post-shoot: edit notes, voiceovers) | Written from scratch after the trip, from memory + footage scrubbing | Generated as `TripArtifact(kind: script)` when a trip is completed; owner can share markdown / `.arcguide` from review | Deepen the script editor and make edits flow cleanly back into the artifact |

The SCRIPT artifact is **bidirectional**: unlike IDEAS and SHOOT LIST (inputs), Arc produces it as output from what actually happened in the field, and the owner refines it. This closes the loop that makes execution data valuable — see field-verified provenance in §4.

## 3. Core loop

### Current (branch `task-owner-mvp-through-p4`)

1. Paste/share/open a trip plan or `.arcguide` into `ImportPlanFlowView`.
2. T0/T1/T2 import produces an `ArcPlanDocument`; structured `.arcguide` files skip parsing.
3. Commit creates a schema-v2 `Trip` graph: `Trip -> ShootDay -> Stop -> Stage -> CaptureItem`, with source text stored as a `TripArtifact`.
4. Execute in `FieldView` with trip timeline, map, stop switching, stage mantra, capture / skip / note / photo, and high-contrast mode.
5. Add Story Safety Net items on demand into one `Stage(kind: safetyNet)` per stop.
6. Complete the trip to generate `TripArtifact(kind: script)`.
7. Review in `CompletedShootView`; export markdown or a structured `.arcguide`.

### Target (remaining end state across P3–P5; phasing in [docs/08-roadmap.md](08-roadmap.md))

1. Tighten field mode around a true no-scroll **glanceable stage mantra** (Stage.goal + musts remaining) and done-enough state ([docs/07-field-ux.md](07-field-ux.md)).
2. Add golden-hour nudges and optional while-in-use stop surfacing / Live Activity after G1.
3. Improve review so the SCRIPT artifact becomes an editable post-shoot workspace, not just generated markdown.
4. Export a **field-verified guide** (`.arcguide`, [ADR-0004](adr/ADR-0004-arcguide-document-interchange.md)) with off-app web preview and email capture after G2 ([ADR-0006](adr/ADR-0006-email-capture-and-paid-guides.md)).

## 4. Positioning conclusions

Evidence and full competitive table: [docs/03-market-research.md](03-market-research.md). Business gates that phase this in: [docs/02-business.md](02-business.md). Verified July 2026.

| Conclusion | Statement |
|---|---|
| **Whitespace** | "Trip plan → staged in-field capture checklist" is unoccupied. No product parses a freeform trip plan into staged field guides — verified across production tools, creator apps, templates, and travel apps. |
| **Moat** | Story-coverage mechanics — Must tiers, voice/sound/transition items, Story Safety Net — exist nowhere else and are hard to bolt onto a flat-list app. |
| **True incumbent** | Free Notion templates + printed PDFs. The desk layer is "good enough" and free; Arc must not compete on plan storage. Arc's defensible ground is execution-time, in the field. |
| **Nearest product** | SimplistUGC ($2.99/mo): AI shot lists, in-field check-off, location-triggered surfacing — but flat lists, no trips, no stages, no story coverage. Also the primary threat watch: a "trip mode" there narrows Arc's window. |
| **NOT a marketplace** | Rexby, Thatch/Mindtrip own map-guide marketplaces with multi-year head starts and compressing take rates. Arc never competes there. Arc is the execution + provenance layer those products lack. |
| **Field-verified provenance** | Post-Thatch, buyers and creators fear AI guide slop; competitors market authenticity but cannot prove it. Guides auto-drafted from executed trips (timestamps, skipped-stop pruning, field notes) are technically provable "field-verified" — Arc can win this. |
| **Execution telemetry as future moat** | Every marketplace ends at "here's the map." Capture/skip/note data per stop is data no map-guide product has, and it compounds with every trip executed through Arc. |

## 5. Binding product principles

Numbered for citation (e.g., "violates P-3"). These bind all feature and design decisions; conflicts escalate to the owner.

1. **Safety net, not taskmaster.** The app exists to catch forgotten shots, never to guilt a tired creator — burnout is a documented failure mode of this career.
2. **Glanceable over scrollable.** Creators memorize formulas and glance at checkpoints; a scrolling checklist fights real field behavior ([docs/07-field-ux.md](07-field-ux.md)).
3. **Offline-first field mode.** Shoots happen on ferries, trails, and foreign SIMs; no field interaction may require a network round-trip.
4. **Done-enough over 100% completion.** "Story is safe" is the win state; residual optional items are noise, not debt.
5. **Privacy-first, on-device AI preferred.** T1 on-device parsing is the default; cloud (T2) is opt-in and never a dependency ([ADR-0001](adr/ADR-0001-tiered-import.md)). Trip data stays on device.
6. **Apple-frameworks-first.** SwiftUI, SwiftData, Foundation Models, CloudKit before any third-party dependency or backend ([ADR-0005](adr/ADR-0005-backend-deferred-cloudkit-first.md)) — one person maintains this for a 5–10 year business.
7. **Outdoor readability — high contrast is not optional.** Field mode is used in direct sun with wet or gloved hands; contrast, tap-target size, and battery-light rendering are acceptance criteria, not polish.
8. **Dogfood-first.** Nothing ships to anyone but the owner before the G-gates in [docs/02-business.md](02-business.md) are met; the owner's real trips are the only validation that counts pre-G1.

## 6. Non-goals (permanent or long-deferred)

Do not build, propose, or scaffold these. Phase non-goals in [docs/08-roadmap.md](08-roadmap.md) beat everything, per the precedence rule in [docs/00-index.md](00-index.md).

| Non-goal | Why |
|---|---|
| Pro camera / RAW / Log workflows | Arc plans and verifies coverage; it is not a camera app. Shot Lister / StudioBinder serve that market. |
| Android | iPhone-first, one owner, Apple-frameworks-first (P-6). No cross-platform pressure exists. |
| Team collaboration | Solo creator product. Crew sync is Shot Lister's territory. |
| Marketplace-first strategy | Crowded, fee-compressed, owned by Rexby/Mindtrip. Arc feeds marketplaces; it does not become one. |
| Background location tracking | Banned by AGENTS.md:30; only the scoped while-in-use amendment in [ADR-0007](adr/ADR-0007-while-in-use-location-surfacing.md) is permitted. |
| Social feed / community features | Attention sink with no path to the core loop; audience lives on YouTube and the email list. |

## 7. Success metrics — dogfood era (pre-G2)

These are the only metrics that matter until the gates in [docs/02-business.md](02-business.md) advance. All are observable from the owner's real trips (see G1 in [docs/02-business.md](02-business.md)).

| Metric | Pass condition |
|---|---|
| **Catch rate** | Arc catches ≥1 shot per trip that the owner would otherwise have missed (surfaced by a Must tier, before-leaving stage, or Safety Net item and then captured). |
| **Script utility** | The Arc-generated SCRIPT artifact is actually used in an edit — opened during editing and materially shaping the cut, not regenerated by hand. |
| **Story is safe, on location** | The owner reaches "story is safe" before leaving a stop, instead of discovering coverage gaps at home in the footage graveyard. |

If a trip fails all three, treat it as a product defect: file what broke against the current phase in [docs/08-roadmap.md](08-roadmap.md).
