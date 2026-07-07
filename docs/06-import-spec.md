# 06 — Import Spec

> **Agent Brief** — Status: Current | Applies to: owner-test MVP import and `.arcguide` round-trip; T3 note is P5+ | Owner doc for: import inputs, Arc-Flavored Plan (AFP) conventions, ChatGPT prompt template, parsing pipeline T0-T3
> Read [docs/00-index.md](00-index.md) first. Behavioral rules: /AGENTS.md (wins on conduct). Current build phase: see [docs/08-roadmap.md](08-roadmap.md).
> Code pointers verified against `task-owner-mvp-through-p4` after Trip mapper/export implementation (2026-07-07). Re-verify line numbers before editing.

This doc is normative for everything between "owner has a trip plan somewhere" and "Arc holds a committed plan." Output schema (`ArcPlanDocument`) is owned by [docs/05-data-model.md](05-data-model.md) and [adr/ADR-0004-arcguide-document-interchange.md](adr/ADR-0004-arcguide-document-interchange.md). Tier decision rationale: [adr/ADR-0001-tiered-import.md](adr/ADR-0001-tiered-import.md).

---

## 1. Accepted inputs

| # | Input | Mechanism | Phase | Implementation notes |
|---|-------|-----------|-------|----------------------|
| 1 | Paste | SwiftUI `PasteButton` plus editable `TextEditor` in `Arc/Features/Shoots/Presentation/ImportPlanFlowView.swift` | P0 exists, P1 polish | `PasteButton` avoids the paste-permission prompt and takes `String.self` payloads. Keep the manual text editor as a secondary path for editing before parse. |
| 2 | Share sheet | Share extension accepting plain text, `.md`, `.txt`, and PDF | P1 | Extension does NOT parse. It extracts a raw string (PDF: `PDFKit` text extraction; if a page yields no text layer, run Vision `VNRecognizeTextRequest` OCR on the rendered page), writes the payload to the App Group container, then deep-links into the main app. Share extensions have a hard low memory ceiling — all tier parsing (T0/T1/T2) runs in the MAIN app only. |
| 3 | Open in Arc | Declare document types for `public.plain-text`, markdown (`net.daringfireball.markdown`), `com.adobe.pdf` | P1 | Enables Files, Mail attachments, and Apple Notes iOS 26 Markdown export ("Export as Markdown" -> share -> Arc). Same handoff path as row 2: raw text into the main-app import flow. |
| 4 | App Intent | `ImportPlanIntent` with an `AttributedString` parameter | P1 | Powers the documented **"Send Note to Arc"** Shortcuts recipe below. Plain-text the attributed string, then feed the normal pipeline. |
| 5 | `.arcguide` file | `UTType com.arc.guide` document open | P1+ | Already-structured `ArcPlanDocument` JSON — skips parsing entirely. See [adr/ADR-0004-arcguide-document-interchange.md](adr/ADR-0004-arcguide-document-interchange.md). |

Owner-test MVP status (2026-07-07): the main app can decode both `kind: plan` and `kind: guide` documents through `ArcDocumentCodec.decodePlanOrGuide`, hand them to the import flow, and commit them directly into the schema-v2 `Trip` graph through `TripDocumentMapper`. The import screen opens directly on the plan editor; it must not require choosing a fallback location before commit. Unresolved imported stops stay unresolved with their `sourceGeoAnchor` until the owner resolves them in the stop info/editor flow. The off-app web preview and email capture path are still gated P4 work.

**Apple Notes, plainly:** there is NO public Apple Notes API and none is coming (Apple TN3132 says to use App Intents/Shortcuts instead). Do not plan, estimate, or stub a Notes importer. The Shortcuts bridge is the only real Notes integration:

**"Send Note to Arc" shortcut recipe** (document this in-app on the import screen):
1. Shortcuts app -> new shortcut -> action **Find Notes** (filter: Folder is "Trips", or "Selected Note" when run from Notes' share sheet).
2. Action **Get Text from Input** (note body).
3. Action **Import Plan** (Arc's `ImportPlanIntent`), passing the text.
4. Name it "Send Note to Arc"; add to Home Screen / Action Button.

**Future (upgrade note only, do not build now):** iOS 27 Foundation Models multimodal prompts accept images — screenshot-of-itinerary and PDF-page-as-image import become possible without OCR. Revisit at P5. See T3 in section 4.

---

## 2. Arc-Flavored Plan (AFP) conventions — normative

AFP is the markdown dialect T0 **guarantees** to parse. Everything else is best-effort. These conventions deliberately align with (and extend) the shipped heuristics in `Arc/Features/Planning/Domain/ImportedPlanParser.swift` — heading detection at lines 82-111, before-leaving detection at 113-118, kind inference at 165-183, priority inference at 185-200, auto leaving-transition at 202-218, chunked fallback at 220-231.

| Convention | Rule | Parser behavior |
|------------|------|-----------------|
| Plan title | First `#` heading, or the import screen's title field | Plan title |
| Day heading | `## Day N: <name>` (`day`/`stage`/`scene`/`part` + number is recognized) | Starts a `ShootDay`; also defines the chunk boundary for T1 |
| Stop heading | `### Stop: <name>` OR a time-prefixed line like `9:00 AM - Harbor walk` | Starts a `Stop`. Time-prefixed form: the whole line is preserved verbatim as the geo anchor |
| Geo anchor | A Google Maps URL (`maps.google.com`, `goo.gl/maps`, `maps.app.goo.gl`) or a full postal address on its own line directly under a stop heading | Preserved VERBATIM into `Stop.sourceGeoAnchor`. Never treated as an item. Never geocoded at import time |
| Stage heading | Short line ending with `:` (also: short non-bullet lines <= 7 words, no `.`/`?`, not starting with capture/film/record/shoot) | Starts a `Stage` (kind `standard`) |
| Item | Bullet `- title - guidance` (also `*`, `•`, `1.`, `1)`). Title is text before the first ` - `/` — `/` – `/`:` separator, max 72 chars; the rest is guidance | One `CaptureItem` (origin `planned`) |
| Priority markers | `(must)` / `(optional)` at end of line | Explicit marker wins over keyword inference (`important`, `establish`, `nice to`, ...). Strip the marker from stored text. Unmarked items default to must; before-leaving items are always must |
| Kind prefixes | Bullet starts with `voice:`, `sound:`, `transition:`, or `note:` | Sets item kind explicitly; prefix beats keyword inference; strip prefix from stored title. No prefix = `shot` (default) |
| Before-leaving block | Line `Before you leave:` (also matches "before leaving", "before moving on") inside a stop | All following bullets until the next heading get `isBeforeLeaving = true` and roll into the stop's `beforeLeaving` stage |
| Auto leaving-transition | (not authored — synthesized) | Any stage/stop with zero before-leaving items gets a synthetic "Leaving transition" item, marked synthetic (see invariants) |

Known deltas the P1 T0 rewrite must close (current parser flattens everything into stages): no day/stop hierarchy yet, maps-URL lines currently fall through to `itemDraft` and become junk items, kind prefixes and `(must)`/`(optional)` markers are matched only by substring accident and are not stripped from titles.

### Complete AFP example (covers every convention)

```markdown
# Copenhagen — 2 Days of Hidden Corners

## Day 1: Old Town

### Stop: Nyhavn Harbor
https://maps.google.com/?q=Nyhavn,+Copenhagen

Arrival:
- Establishing wide of the colored houses - hold 8s, include water in frame (must)
- voice: First impression line to camera - one honest sentence, no script (must)
- sound: Ambient harbor audio - 30s clean, boats and gulls (optional)

Boat tour:
- Detail of ropes and hulls - slow pan, low angle
- transition: Boarding shot - follow feet up the gangway (must)
- note: Ask captain if the bridge lift happens today

Before you leave:
- Leaving transition - walk-away shot toward Kongens Nytorv (must)
- voice: One-line stop recap - what surprised you here (must)

9:00 AM - Round Tower climb
Købmagergade 52A, 1150 København

Spiral ramp:
- POV walking up the ramp - gimbal, steady pace (must)
- sound: Footsteps echoing in the tower - 15s clean (optional)

Rooftop view:
- Panorama over the rooftops - slow 180 pan (must)
- transition: Arriving at the top - door push into the light

Before you leave:
- Leaving transition - descending timelapse (must)

## Day 2: Waterfront

### Stop: Reffen Street Food
https://maps.app.goo.gl/abc123

Food run:
- Vendor flames close-up - handheld, expose for the fire (must)
- voice: Taste reaction - unscripted first bite (must)
- Crowd tables wide - 10s locked-off (optional)

Before you leave:
- sound: Market walla - 20s clean bed (must)
- Leaving transition - bike ride out along the quay (must)
```

---

## 3. ChatGPT prompt template

The owner generates most trip plans in ChatGPT. Shipping this template is the cheapest parsing win in the system — zero code, and it makes T0 alone sufficient for the primary source. Surface it in-app (import screen -> "Copy ChatGPT template") and keep this block byte-identical to the in-app copy.

```text
You are formatting a video shoot plan for the Arc app. Output ONLY the plan in
exactly this markdown structure — no intro, no outro, no explanations, no prose
outside the structure.

Structure (follow it exactly):

# <Trip title>

## Day 1: <day theme>

### Stop: <place name>
<Google Maps link for this exact place, on its own line>

<Stage name>:
- <shot title> - <one line of how to shoot it> (must)
- voice: <line to say to camera> - <delivery note> (must)
- sound: <audio to record> - <length and quality note> (optional)
- transition: <movement shot> - <how to shoot it>
- note: <reminder that is not a shot>

Before you leave:
- <final must-have before departing> (must)

Rules:
1. Every stop MUST have a Google Maps link on its own line directly under the
   "### Stop:" heading.
2. Every stop has 2-5 stages. Every stage has 3-7 bullet items.
3. Every item is one bullet: "title - guidance". Never multi-line.
4. Mark truly essential items "(must)" and skippable ones "(optional)".
   3-6 musts per stop, no more.
5. Every stop includes at least one voice: item, one sound: item, and one
   transition: item somewhere in its stages.
6. Every stop ends with a "Before you leave:" block of 1-3 items.
7. Stage names are short (2-5 words) and always end with a colon.
8. No text anywhere outside this structure. No tables, no blockquotes,
   no nested bullets.

Here is my trip plan / idea dump — convert it:

<PASTE TRIP NOTES HERE>
```

---

## 4. Parsing pipeline (normative)

Every tier implements the same contract: **input text -> `ArcPlanDocument`** (`kind: plan`, see [docs/05-data-model.md](05-data-model.md)). Tiers differ only in intelligence, never in output shape. Structured `.arcguide` import starts from an already-decoded `ArcPlanDocument` and skips tier parsing.

| Tier | Engine | Availability | Role |
|------|--------|--------------|------|
| T0 | Rule-based AFP parser (rewrite of `ImportedPlanParser` to emit `ArcPlanDocument` with day/stop hierarchy) | Always, offline, deterministic | Universal fallback. ALWAYS runs — its day detection also produces the chunk map for T1, and its output is the ready fallback for any higher-tier failure |
| T1 | Apple Foundation Models, on-device, `@Generable` structured output | iOS 26, gated on `SystemLanguageModel.default.availability` | Default smart tier. Retitles, regroups, classifies messy non-AFP text. 4,096-token window -> chunk per detected day |
| T2 | Cloud LLM via existing OpenAI-compatible path (`Arc/Services/AI/OpenAICompatibleAIService`; `ImportedPlanGenerator.swift` is the seed to refactor) | User opt-in only, never a dependency | Optional quality boost for very messy sources. Off by default; no Arc feature may require it |
| T3 | `PrivateCloudComputeLanguageModel` (iOS 27, 32K context) | Future | Upgrade note only. Whole-plan single-shot parsing, multimodal input. Do not build before P5 |

**Selection order:** T2 if the user opted in and is online -> else T1 if available -> else T0. **Any tier failure falls back exactly one tier, silently** — no error alert, no retry dialog; show a small one-line notice on the draft screen ("Parsed with basic rules" / "Parsed on-device"). The user always gets a draft.

**Contract every tier MUST satisfy:**

1. Output is a valid `ArcPlanDocument` (`schemaVersion` current, `kind: plan`).
2. T1/T2 MAY retitle stages, regroup items, reorder within a stop, and reclassify kind/priority. They MUST NOT drop source lines: every non-empty source line is either represented by an item's `sourceLine`, preserved as a `sourceGeoAnchor`, consumed as a heading, or recorded in the document's unparsed-remainder field ([docs/05-data-model.md](05-data-model.md)).
3. Every item carries `sourceLine` (verbatim source text) OR an explicit synthetic marker (auto leaving-transition, tier-invented items). No third state.
4. Geo anchors pass through verbatim — no tier may "clean up," shorten, or resolve a maps URL or address.
5. Tiers are pure functions over text. No tier touches SwiftData, network state (except T2's own call), or app storage.

Pipeline output feeds the draft/edit/commit flow (`ImportPlanFlowView` today). Committing the draft is the ONLY storage write (invariant 5, section 6).

---

## 5. Foundation Models (T1) implementation notes

- **Gate on `SystemLanguageModel.default.availability`** and give each reason distinct UX — never a generic "AI unavailable":

  | Availability | UX |
  |--------------|-----|
  | `.available` | No UI; T1 is the silent default |
  | `.unavailable(.deviceNotEligible)` | Say nothing about AI at all. T0 is simply "how import works" on this device |
  | `.unavailable(.appleIntelligenceNotEnabled)` | One-line hint with a deep link to Settings: "Turn on Apple Intelligence for smarter imports" |
  | `.unavailable(.modelNotReady)` | "Smart parsing is downloading — using basic parsing for now." Re-check on next import |

- **Prewarm:** create the `LanguageModelSession` and call `prewarm()` when the import screen appears (`.task` on `ImportPlanFlowView`), not when the user taps Parse. Saves the multi-second cold start.
- **Chunk per detected day**, reusing T0's day detection (do not write a second day detector). One `@Generable` request per day chunk; merge results in source order. A failed chunk degrades ONLY that day to T0 output — never the whole plan.
- **Token budget:** the 4,096-token window covers prompt + instructions + output. Budget roughly 2,000 input tokens per chunk. On iOS 26.4+ measure with the `tokenCount` API; below 26.4 estimate at ~4 characters/token for English. If a single day exceeds budget, split the chunk at stage-heading boundaries.
- **`guardrailViolation` false positives are expected** on benign travel text (place names, "shoot", "capture"). Catch `LanguageModelSession.GenerationError.guardrailViolation`, use the T0 output for that chunk, log for the corpus ([docs/09-quality.md](09-quality.md)), and show nothing alarming to the user.
- **Schema design:** the `@Generable` types mirror `ArcPlanDocument` day/stop/stage/item shapes but stay separate structs — Foundation Models types must not leak into `Arc/Core/Documents/` (that folder has its own no-SwiftData rule; keep it framework-free generally).

---

## 6. Invariants

1. **Never lose source lines.** The full pasted/shared text is stored on the `ArcPlanDocument`; every source line is accounted for per contract rule 2 in section 4. A user must always be able to see what the parser was given.
2. **Every item is traceable or marked synthetic.** `sourceLine` or synthetic marker — enforced at document validation, not by convention.
3. **Geo anchors are preserved verbatim** into `Stop.sourceGeoAnchor`. No geocoding, no URL unshortening, no coordinate writes during parse. Never fabricate coordinates. Schema v2 makes `Stop.latitude` / `Stop.longitude` optional, so unresolved imported stops stay honest until the owner sets a precise location.
4. **Import works fully offline via T0.** No spinner that depends on network or model download may block producing a draft.
5. **Committing a draft is the only write to storage.** Parse, tier fallback, and draft editing are pure/in-memory. The current commit path maps `ArcPlanDocument` into `Trip -> ShootDay -> Stop -> Stage -> CaptureItem`, stores the original source as a `TripArtifact`, and does not ask for or fabricate fallback coordinates.

---

## 7. Quality bar

Corpus, thresholds, and the import test harness live in [docs/09-quality.md](09-quality.md). The P1 gate that matters here: **output of the section 3 ChatGPT template must parse 100 percent on T0 alone** — every day, stop, geo anchor, stage, item, kind, priority, and before-leaving block lands correctly with no tier above T0 involved. Real freeform Apple Notes samples have their own (lower) thresholds in docs/09; the template corpus has no tolerance because the template is under our control.
