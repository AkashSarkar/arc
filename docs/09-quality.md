# 09 — Quality: Tests, Eval Harness, Manual Verification

> **Agent Brief** — Status: Current | Applies to: All phases (thresholds ratchet per phase) | Owner doc for: test target, parsing eval harness, per-layer test policy, manual golden path, Foundation Models tier evaluation
> Read [docs/00-index.md](00-index.md) first. Behavioral rules: /AGENTS.md (wins on conduct). Current build phase: see [docs/08-roadmap.md](08-roadmap.md).
> Code pointers verified against ux-redesign @ abce4bc + uncommitted field-guide work (2026-07-06). Re-verify line numbers before editing.

## 1. Test target setup: `ArcTests`

There is **no test target today**. Creating one is a **P0 Stabilize work item** (see [docs/08-roadmap.md](08-roadmap.md)).

| Decision | Value |
|---|---|
| Target name | `ArcTests` |
| Framework | XCTest, plain `XCTestCase` (no Swift Testing migration yet; revisit in P2) |
| UI test target | **None initially.** Do not create `ArcUITests`. SwiftUI views are covered by the manual golden path (section 5). |
| Network | Tests MUST run fully offline. No live HTTP, no API keys, no Keychain reads. Anything network-shaped goes through a protocol fake (section 4). |
| Data | Use in-memory `ModelContainer` for any SwiftData test. Never touch the app's store. |
| Run command | `xcodebuild test -scheme Arc -project Arc.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/ArcDerivedData` |

Rules for agents:

- A test that requires an API key, a network connection, or a specific simulator state is a defect. Fix the test, not the environment.
- Add tests in the same PR as the code they cover (parsers, generators, codecs — see section 4). "Tests later" is not accepted for those layers.

## 2. Parsing eval harness (import corpus)

The import pipeline ([docs/06-import-spec.md](06-import-spec.md)) is the highest-risk surface in the app. It is guarded by a fixture corpus that runs as ordinary XCTest cases inside `ArcTests` — no separate tooling, no cloud infra.

### Layout

```
ArcTests/Fixtures/ImportCorpus/
  <fixture-name>.md      # raw source text, exactly as pasted (real anonymized input)
  <fixture-name>.json    # expected-structure assertion sidecar, same basename
```

One markdown fixture + one JSON sidecar per case. The harness enumerates the directory, parses each `.md` through the tier under test, and evaluates every assertion in the sidecar.

### Fixture classes

| Class | Contents | Why |
|---|---|---|
| `apple-notes` | Real anonymized Apple Notes exports from the owner's past trips | The dominant real-world source today |
| `chatgpt-template` | ChatGPT-generated markdown following the template conventions in [docs/06-import-spec.md](06-import-spec.md) (Arc-Flavored Plan) | The format T0 guarantees to parse |
| `adversarial` | No headings; emoji bullets; day boundaries merged into one block; mixed prose and bullets; other degradations found in the wild | Keeps T0's universal fallback honest |

Anonymize real fixtures before committing: strip names, exact addresses, and personal notes, but **preserve structure and geo-anchor shapes** (Google Maps links, address lines, time prefixes) since those are what the parser must handle.

### Assertion sidecar coverage

Each `.json` sidecar declares assertions over the parsed structure. Cover:

| Assertion | Example |
|---|---|
| Stage count range | `"stageCount": {"min": 4, "max": 6}` |
| Day / stop detection | expected day count; expected stop titles (fuzzy or exact) |
| Kind inference | which items resolve to voice/sound/transition vs. standard capture |
| Priority inference | which items are must-tier |
| Before-leaving detection | items that must land in the `beforeLeaving` stage |
| Geo-anchor extraction | verbatim source lines expected in `Stop.sourceGeoAnchor` (see glossary in [docs/00-index.md](00-index.md)) |

### Scoring

- Per fixture: **percentage of assertions met** (each assertion is pass/fail; no partial credit within an assertion).
- Per class: mean of fixture scores, reported per class (`apple-notes`, `chatgpt-template`, `adversarial`).
- The harness prints a per-class summary in test output so regressions are visible in one line per class.

## 3. Ratcheting thresholds per phase

Thresholds only move up. **Corpus green is a merge requirement** — it is the cross-cutting track in [docs/08-roadmap.md](08-roadmap.md). The corpus grows with every real trip the owner imports: after each trip, add the raw paste as a new `apple-notes` fixture with a sidecar before starting the next feature.

| Phase | Requirement |
|---|---|
| P0 Stabilize | Lock in **existing** parser behavior (`ImportedPlanParser.swift`): write sidecars that encode what the current parser produces on the initial corpus. No regressions from that baseline. Do not chase improvements in P0. |
| P1 Import pipeline v2 | Day/stop detection targets met on the full corpus. `chatgpt-template` class parses **100% on T0 alone** (no AI tier). Geo anchors extracted **verbatim** — byte-for-byte match against source lines. |
| P2+ Schema v2 | Add document → storage mapper round-trip tests: `ArcPlanDocument` → schema v2 entities → `ArcPlanDocument` must be lossless for every corpus fixture (see [ADR-0004](adr/ADR-0004-arcguide-document-interchange.md) and [docs/05-data-model.md](05-data-model.md)). |

If a new fixture drops a class below its phase threshold, that is a real parser gap — fix the parser or explicitly annotate the fixture as a known limitation with a linked roadmap item. Never delete a fixture to go green.

## 4. Unit-test policy per layer

| Layer | Policy | Notes |
|---|---|---|
| Parsers (`ImportedPlanParser`, T0 heuristics, per-day chunker) | **Mandatory tests** | Covered primarily by the corpus harness (section 2) plus targeted unit tests for edge functions |
| Generators (`ImportedPlanGenerator`, script generation, guide export) | **Mandatory tests** | Test the pure transform (input → draft/document); AI calls go through a fake `AIServicing` |
| Document codecs (`ArcPlanDocument` / `ArcGuideDocument` encode/decode, schema-version handling) | **Mandatory tests** | Include unknown-field tolerance and schemaVersion mismatch cases; these codecs live in `Arc/Core/Documents/` which must never import SwiftData |
| Services | Behind protocols with fakes | `AIServicing` and `LocationEnriching` already exist as protocols — write fakes in `ArcTests`, do not add new test hooks to production types. New services MUST be introduced protocol-first so they are fakeable. |
| SwiftUI views | **Manual golden path only** (section 5) | No snapshot or UI tests initially; view logic that grows complex enough to want tests should be extracted into a testable type instead |

## 5. Manual golden-path checklist

Ported from the pre-docs README; README now links here instead of carrying its own copy. Run the full checklist after any UX or persistence change, on a physical device when field behavior is involved.

1. Empty launch shows Capture Plans and a New Capture Plan CTA.
2. New Capture Plan defaults to current GPS and still supports search and map pin.
3. Invalid custom timing blocks progress before generation.
4. Generate fetches context and produces a reviewable draft.
5. Start Capture Plan commits the location, plan, and shot list.
6. Import Existing Plan accepts pasted Apple Notes text, builds editable stages locally, and can optionally improve the draft with AI. (Regression checks for the implemented P0 fixes: committed location uses the picked coordinates — `ImportPlanFlowView.swift:495-499`; edited stage goal survives commit — `:535` in the item loop at `:522-545`.)
7. Field progress updates as items are captured or skipped.
8. Before You Leave blocks accidental stage advancement while must-have or leaving items are unresolved.
9. Story Safety Net adds recovery coverage to the current stage. (Regression check for the implemented P0 fix: repeated Safety Net taps add no duplicate unresolved items — dedup guard at `FieldView.swift:548-555`.)
10. Capturing or skipping the final item shows a completion prompt and does not auto-complete.
11. Complete Plan moves it to Completed with captured, skipped, missing, and stage-grouped export sections.
12. Reopen moves the plan back to Active.
13. Relaunch preserves Active and Completed state.

When a step's behavior changes by design (e.g., schema v2 replaces the commit path in P2), update this checklist in the same PR — keep all scenarios, reworded to match the new behavior.

## 6. Foundation Models tier evaluation (device-only)

T1 (on-device Apple Foundation Models, see [docs/06-import-spec.md](06-import-spec.md)) cannot run in CI or on Simulator reliably — evaluate it manually on a physical device. **No cloud eval infra**; this is a device-run diff, not a hosted pipeline.

Procedure:

1. On a physical iPhone (iOS 26, Apple Intelligence enabled), run the corpus through **T0 alone**, then through **T0 + T1**.
2. Diff the structured outputs per fixture (stage/stop/item structure, kinds, priorities, geo anchors).
3. Record each win or regression as a **fixture annotation**: a `t1Notes` field in the fixture's JSON sidecar describing what T1 improved or broke, with the run date and device OS version.
4. A T1 regression on the `chatgpt-template` class is disqualifying for that fixture — T0 must remain the guaranteed floor (per [ADR-0001](adr/ADR-0001-tiered-import.md), guardrail violations fall back to T0).
5. Re-run after each iOS point release that touches Apple Intelligence, and before enabling T1 by default for a phase.

T2 (optional cloud) is user-opt-in and never a dependency; it gets no automated eval — spot-check it manually against the same corpus when its prompt changes.
