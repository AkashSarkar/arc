# 03 — Market Research (Snapshot: July 2026)

> **Agent Brief** — Status: Current | Applies to: All (decision-critical before P4/P5) | Owner doc for: competitive landscape, whitespace analysis, creator behavioral evidence, import-tech landscape, pricing/take-rate norms
> Read [docs/00-index.md](00-index.md) first. Behavioral rules: /AGENTS.md (wins on conduct). Current build phase: see [docs/08-roadmap.md](08-roadmap.md).
> Code pointers verified against ux-redesign @ abce4bc + uncommitted field-guide work (2026-07-06). Re-verify line numbers before editing.

> **Snapshot as of 2026-07. Do NOT cite as current truth — verify before strategic decisions. Refresh triggers: before P4 kickoff, before P5 kickoff.**

This doc is the evidence base behind the positioning in [docs/01-product.md](01-product.md), the phase gates in [docs/02-business.md](02-business.md), and the tiered import design in [docs/06-import-spec.md](06-import-spec.md) / [ADR-0001](adr/ADR-0001-tiered-import.md). When this doc and the roadmap disagree, the roadmap wins on what to build now; this doc only records what the market looked like in July 2026.

## 1. Method

Four parallel research sweeps ran in July 2026, followed by a synthesis pass. Every claim below carries a source tag:

| Tag | Sweep | Scope |
|---|---|---|
| [SP] | shot-planning-apps | Pro shot-list tools, creator capture apps, planning templates, light/scouting apps |
| [IP] | itinerary-platforms | Trip planners, creator guide marketplaces, informal guide economy |
| [IT] | import-and-ai-tech | Apple Notes ingestion paths, on-device/cloud LLM parsing, structured output |
| [CP] | creator-painpoints | Solo travel creator in-field failures, workflow tooling, burnout evidence |

**Method caveat [CP]:** Reddit blocks Anthropic's crawler. Creator-voice evidence was triangulated from creator-authored blogs/courses, Quora, tool marketplaces, and 2025 burnout reporting — converging secondary signals, not primary forum threads. Direct first-person evidence on mid-shoot phone behavior is thin; treat the memorize-plus-glance model (Section 4) as well-supported inference, not proven fact.

## 2. Competitive Landscape

Two markets matter: **shot planning / field capture** (today's product) and **itinerary platforms / creator marketplaces** (the long-term vision). Neither contains a direct competitor; both contain adjacent players that define price and UX expectations.

| Product | Category | Price | What it does | Key gap vs Arc | Sweep |
|---|---|---|---|---|---|
| **SimplistUGC** | UGC shot-list planner (closest competitor) | Free + $2.99/mo or $24.99/yr | AI brief→shot list per platform; in-field check-off; **location-triggered plan surfacing**; solo dev, launched Mar 2024 | No trip/itinerary ingestion, no multi-day trips, flat list (no stages/tiers), no story coverage, no fallbacks, no post-shoot review | [SP] |
| **Shot Lister** | Pro film shot lists | Free + ~$10–14/mo Pro | Shot lists + schedules; "Live mode" on-set execution; crew sync | Script/scene paradigm; no text import, no story coverage, no travel context; heavy for solo creators | [SP] |
| **ShotList (Soluble)** | Pro film shot lists | ~$11.99 one-time | Stripboard shot planning; solo progress tracking; offline | Film grammar, not story coverage; fully manual; dated; no staging/fallbacks | [SP] |
| **StudioBinder** | Production suite | Free tier; $42–$340/mo | Shot lists, storyboards, call sheets for teams | Priced/shaped for production companies; no offline field mode, no trip ingestion | [SP] |
| **Filmustage / Studiovity** | AI pre-production | ~$49/mo / freemium | AI screenplay→breakdowns/shot lists | Input is a screenplay, not a trip plan; desktop paperwork, not field execution. Watch: this AI pattern moving downmarket is the most plausible path to a real Arc competitor | [SP] |
| **Reelshot** | Vlog camera | Freemium sub | Organizes A-roll vs B-roll while filming; pre-assembles edit | No planning at all — organizes what you happened to shoot | [SP] |
| **Unscripted** | Photographer posing prompts | Subscription | 20,000+ posing prompts served mid-shoot + CRM | Portrait posing, not travel story coverage; proves "in-field guidance" is a paid category | [SP] |
| **PhotoPills / Lumy / Sun Surveyor / Alpenglow / Clear Outside** | Light/conditions | $6.99–$10.99 one-time / freemium | Sun, golden hour, cloud forecasts | Single-question tools ("when is light good"); none know what you're making. Complements, not competitors | [SP] |
| **Explorest / PhotoSpot** | Photo-spot discovery | $49.99/yr / $5.99/mo | Curated GPS photo locations, best times | Where to stand, not what your video needs; PhotoSpot *removed* its AI trip creator in 2024 | [SP] |
| **Milanote / Notion templates** (Later, Thomas Frank, Katie Steckly's Travel Vlog Planner) | Desk-layer planning — **the true incumbent** | Free–$9.99/mo | Boards, databases, shot-list and travel-vlog templates | No staged execution, no coverage checking, painful on a phone in the field | [SP][CP] |
| **Wanderlog** | Consumer trip planner | Free + ~$39.99/yr Pro | Collaborative map itineraries, Google Maps import, offline (Pro) | No creator monetization, no capture concept; AI rated poorly | [IP] |
| **TripIt** | Utility itinerary | Free + $49/yr | Email-forward parsing to master itinerary | Aging; "not worth $49" per 2026 reviews; no map-first, no creator angle | [IP] |
| **Stippl** | All-in-one planner | Freemium, ~$9.99/mo | Itinerary + budget + AI planner; affiliate-only creator program | Creators earn on bookings, not guide sales; stability complaints | [IP] |
| **Polarsteps** | Trip tracking (18–20M users, profitable) | Free | Auto tracking; 2025 AI itinerary builder built with Claude; physical Travel Books | Editorial, no creator marketplace — deliberately chose editorial over creator economy | [IP] |
| **Rexby** | Creator guide marketplace ($4M seed Nov 2025) | Guides $0–49; creator keeps ~80% own-audience; Rexby takes up to ~50% marketplace | Interactive map guides + AI assistant on creator's content; top guides $5–15K/mo | Guide is a *reading* product; no execution layer; take rate resented; thin buyer-side reviews | [IP][SP] |
| **Thatch → Mindtrip** | Marketplace absorbed by AI planner (Mar 2025) | Was 90% to creators; now $1–1.50/referred user + tips + commissions | AI trip planner with 40K+ guides; DMO/airline/card investors | Creators became traffic acquisition for an AI product; "From Thatch to Trash" backlash | [IP] |
| **Hotspot** | Anti-AI creator marketplace (2025) | 10% flat fee, direct Stripe payouts | Thatch-migration positioning; CSV/Maps import | No traction numbers; markets provenance but cannot technically prove it | [IP] |
| **GuideGeek / TripScout / Passporter** | Substitutes & cautionary tales | Free / B2B | Free AI travel assistant (DMO-licensed); TripScout pivoted consumer→DMO agency | Free conversational AI erodes low-effort paid guides; consumer guide monetization did not sustain venture scale | [IP] |
| **Gumroad/Stan Store + Google Maps lists** | Informal economy | $5–50/guide | Creators sell private Maps links ($20K+ documented cases) | This, plus PDFs and Notion docs, is the actual incumbent for the sharing vision | [IP] |
| **Reelstrip / Triply / Map Your Voyage** | Reel→location extractors | Various | Extract locations from saved TikToks/reels | Stop at mapping places; never convert inspiration into an executable capture plan | [CP] |

The one historical attempt at Arc's exact category — My Shot Lists for Travel (~2011) — is dead [SP].

## 3. Whitespace Analysis

### 3.1 Genuinely differentiated (verified unoccupied)

- **Trip plan → staged in-field capture checklist: nobody does it.** Verified across production tools, creator apps, templates, and travel apps — no product parses a freeform trip plan into staged field guides [SP].
- **Story-coverage checking is Arc's deepest moat.** Must tiers, voice/sound/transition prompts, and Story Safety Net fallback shots exist *nowhere* in the market, and are hard to bolt onto a flat-list app [SP].
- **Buyer-side execution is unserved in the itinerary market.** Every marketplace ends at "here's the map"; nothing guides the traveler on the ground, tracks what they did, or feeds completion data back [IP].
- **Provenance is a new battleground Arc can actually win.** Post-Thatch, creators and buyers fear AI guide slop; Hotspot markets authenticity but cannot prove it. Arc guides generated from executed trips (timestamps, skipped-stop pruning, field notes) are technically provable as "field-verified" [IP]. This is the basis for [ADR-0004](adr/ADR-0004-arcguide-document-interchange.md) and the P4/P5 vision in [docs/08-roadmap.md](08-roadmap.md).
- **Creator-to-creator "how to shoot this destination" is an empty category** with the highest willingness-to-pay buyers [IP].

### 3.2 Crowded — do not compete head-on

- **Shareable map-itinerary marketplaces.** Rexby and Thatch/Mindtrip have multi-year head starts and creator supply; "interactive map + day-by-day" is table stakes and fees are compressing to 10–20% [SP][IP]. Arc is the execution + provenance layer, not another marketplace.
- **Plan storage / the desk layer.** Free Notion templates, Milanote, and printed PDFs are "good enough" for planning; Arc's defensible ground is execution time, not storage [SP][CP].
- **Light/timing tools.** An entire app ecosystem answers "when is the light good" — consume this data (Arc already has `SunMoonCalculator` and `OpenMeteoAPIClient` in `Arc/Services/Enrichment/`), do not rebuild it [SP][CP].
- **Generic AI shot-list generation.** SimplistUGC (creator tier) and Filmustage/Studiovity (pro tier) already do text→shots [SP].

### 3.3 Threat watch

| Threat | Trigger to watch | Why it matters |
|---|---|---|
| SimplistUGC adds a trip mode | Multi-day trips, itinerary ingestion, or stage grouping in release notes | Already ships first on three of Arc's mechanics: AI generation, in-field check-off, location-triggered surfacing [SP] |
| Reelshot adds pre-planned checklists | Planning features in its A-roll/B-roll camera | Would connect planning to its existing in-camera capture organization [SP] |
| Filmustage/Studiovity-style AI moves downmarket | Solo-creator pricing tier, non-screenplay input | AI text→shot-list at pro quality reaching $5–10/mo territory narrows Arc's window [SP] |

Any of these narrows the window. Implication: speed on P1–P3 matters more than polish (see [docs/08-roadmap.md](08-roadmap.md)).

## 4. Creator Behavioral Findings

Governs the field UX contract in [docs/07-field-ux.md](07-field-ux.md). Method caveat from Section 1 applies.

### 4.1 Validated concepts

| Arc concept | Evidence |
|---|---|
| Staged field guide, Must tier first | "Insufficient B-Roll" is the #1 named travel-vlogger mistake and "Missing Storyline" is #2 (AMaeTV); forgotten establishing shots recur (FlyingChalks); "with travel filming there is no do-over once you leave a destination" (PeekAtThis); Lost LeBlanc pre-researches locations specifically to plan shots. Must-vs-optional tiering mirrors how time-pressured creators already triage under golden-hour compression [CP] |
| Story Safety Net | Event-videography doctrine explicitly uses "safety net" coverage language; the memorized 5-shot rule and 3-shot sequence are the field-standard fallback vocabulary; codifying universal fallbacks (establishing, walking transition, doorway) is exactly what educators teach. No competitor has anything like it [CP][SP] |
| Post-shoot review / edit outline | Top downstream complaint is the footage graveyard — "overwhelmed with the amount of travel video footage," unable to cut a film because no story was captured (Quora); "random clips over music will get a C grade" (Lost LeBlanc) [CP] |
| Before You Leave stage | Battery/card rituals (spares stored at 40–60%, formatted cards, power banks, offline maps) are universally repeated in creator gear guides; "before you go" sections are near-universal in real itineraries [CP][IT] |
| Location-triggered plan surfacing | SimplistUGC ships "plan appears when you arrive" today; the mechanic is market-proven [SP]. Arc's scoped, while-in-use-only version is recorded in [ADR-0007](adr/ADR-0007-while-in-use-location-surfacing.md) (AGENTS.md:22 otherwise bans background location) |

### 4.2 Challenged assumptions — design around these

| Assumption | Finding |
|---|---|
| Creators consult shot lists mid-shoot | **Not real behavior.** Creators memorize formulas and glance at checkpoints (transit, coffee, arrival); the printed-PDF pattern implies glance-based reference. A scrolling checklist fights real behavior — each stage must compress to a glanceable stage mantra (lock screen / Live Activity, huge targets, offline-first, near-zero battery) [CP] |
| Creators want complete checklists | **Rigid checklists get rejected.** Improvisation is identity for run-and-gun creators (Astrologo); Arc must present as safety net + memory prosthetic and celebrate off-plan (fieldAdded) captures [CP] |
| Completion percentage motivates | **It amplifies burnout.** 52% of creators report burnout; some deliberately under-film to protect the experience. The "story is safe / done enough" state ("story is safe — go enjoy") matters; never guilt [CP] |
| Plan storage is a wedge | **It is not.** Notes/Notion/PDFs are good enough for planning; only execution-time guidance is defensible [CP] |
| Mid-shoot behavior is well-evidenced | **Evidence is thin** (Reddit blocked); memorize-plus-glance is inferred from converging secondary signals, not primary threads [CP] |

## 5. Import Tech Landscape

Full design in [docs/06-import-spec.md](06-import-spec.md) and [ADR-0001](adr/ADR-0001-tiered-import.md). Findings as of July 2026 [IT]:

| Fact | Detail | Consequence for Arc |
|---|---|---|
| No public Apple Notes API | Confirmed by TN3132; none is coming | The Shortcuts bridge is the only real Notes integration: ship an `ImportPlanIntent` App Intent (`AttributedString` param) + a pre-built "Send Note to Arc" shortcut |
| iOS 26 Notes Markdown export | Notes gained native Markdown import/export in iOS 26 | Register document types so "Open in Arc" works from Files/Mail/Notes; a share extension (plain text, .md, .txt, PDF) with App Group handoff covers the rest — parse in the main app, not the ~120 MB-limited extension |
| Foundation Models framework (iOS 26) | On-device ~3B model; `@Generable`/`@Guide` guided generation with **constrained decoding guarantees structurally valid output** — no JSON parsing, no malformed-output retries. Apple positions it exactly at extraction + classification into constrained enums | This is import tier T1. `FieldGuideDraft → [Stage] → [Item(category: enum)]` maps directly. Zero cost, fully offline, trip data never leaves device |
| FM hard constraints | 4,096-token context window (iOS 26); A17 Pro/M1+ hardware floor; Apple Intelligence must be enabled; model may be mid-download; `guardrailViolation` false positives; `tokenCount` API on 26.4+ | Chunk per detected day (reuse T0's day/heading detection as the chunker — the two parsers are complementary); gate on `SystemLanguageModel.default.availability` with distinct UX per failure reason; prewarm the session on the import screen; guardrail violation falls back to T0 |
| iOS 27 (~Sept 2026) | `PrivateCloudComputeLanguageModel`: 32K context, no API keys, no developer billing, Apple privacy guarantees; multimodal prompts (screenshots/PDF pages); FM framework opened to any LLM provider | Tier T3 upgrade note only. Removes the main reason to ever build third-party cloud infrastructure; natural home for long third-party-authored itineraries in the guide vision |
| Third-party cloud LLMs | GPT-5-nano-class structured outputs cost ~$0.0006–0.003/parse but need a key-protecting proxy, are online-only, and weaken the privacy story | Tier T2 stays optional/opt-in via the existing OpenAI-compatible path (`Arc/Services/AI/`); never a dependency. Do not build a proxy backend for v1 (see [ADR-0005](adr/ADR-0005-backend-deferred-cloudkit-first.md)) |
| PDF path | PDFKit text extraction → same pipeline; Vision OCR fallback for scans | Cheap add once the share extension exists |
| Geo anchors | Real-world itineraries carry Google Maps links, addresses, and time prefixes | Preserve them verbatim into `Stop.sourceGeoAnchor` during parsing — they become the geo anchors for the P2 map/timeline and the guide vision |

Decisive recommendation from the sweep: tiered, on-device-first pipeline (T0 heuristics always; T1 FM when available; T2 optional cloud; T3 future PCC). Keep the existing heuristic parser (`Arc/Features/Planning/Domain/ImportedPlanParser.swift`) as the deterministic scaffold and universal fallback [IT].

## 6. Pricing and Take-Rate Norms

Business consequences live in [docs/02-business.md](02-business.md) (gates table = single source of truth) and [ADR-0006](adr/ADR-0006-email-capture-and-paid-guides.md). Norms observed July 2026:

| Norm | Observed values | Anchor examples |
|---|---|---|
| Solo-creator capture-tool subscription | Clears at $2.99–$5.99/mo; pro tools start at $42/mo | SimplistUGC $2.99/mo; PhotoSpot $5.99/mo; StudioBinder $42–340/mo [SP] |
| Arc's plausible band | ~$4–8/mo or modest one-time — between SimplistUGC and pro tools | [SP][CP][IP] |
| Per-guide one-time pricing | $10–50, with lifetime "full unlock" tier ~$45–50 | Rexby guides $0–49; informal Gumroad/Maps-list economy $5–50 [IP] |
| Platform take rate | 10–15% is the creator-aligned norm; higher is resented | Hotspot anchored 10% flat + direct Stripe payouts; Thatch was 10% (90% payout) pre-Mindtrip; Rexby's up-to-~50% marketplace take is publicly resented [IP] |
| Buyer-side app | Keep subscription-free to maximize guide distribution | Polarsteps model (free, 18–20M users, profitable) [IP] |
| Distribution reality | Creators drive all traffic (link-in-bio → guide); no discovery marketplace needed at launch — a great share link that opens as a map preview and converts to an executable in-app guide | Rexby + informal economy acquisition pattern [IP] |
| Cautionary pattern | Venture-backed players drifted B2B/DMO or AI-planning and orphaned creators | Thatch→Mindtrip, TripScout→DMO agency, GuideGeek→DMO licensing [IP] |
| Revenue-adjacent data moat | Execution telemetry (what buyers completed/skipped) exists on no platform; impossible to replicate without an execution product | [IP] |

## 7. Top 8 Roadmap Implications

From the synthesis. Phase mapping is owned by [docs/08-roadmap.md](08-roadmap.md); this list only records what the market evidence implies.

1. **Name and claim the category now: "plan in, story out."** Trip plan → staged field guide → coverage assurance → edit outline is verified unoccupied, but SimplistUGC is one pivot away and shipped first on three mechanics — speed matters [SP].
2. **Double down on story coverage as the moat.** Ship voice/sound/transition items and the Story Safety Net with the universal fallback vocabulary (establishing, walking transition, doorway, hands/face close-ups, POV) — zero competition, hard to copy onto flat-list apps, valuable even with no trip-specific plan [SP][CP].
3. **Build the tiered on-device import pipeline:** T0 heuristics + T1 FM `@Generable` (chunked per day, availability-gated), share extension + document types + `ImportPlanIntent`/Notes shortcut; skip third-party cloud dependency; plan the iOS 27 PCC upgrade [IT].
4. **Make field mode glanceable, not scrollable:** Live Activity / lock-screen stage mantras, one-tap confirmation, offline-first, battery-light — and a "done enough / story is safe" state instead of 100%-completion guilt [CP].
5. **Embed light data, do not compete with it:** pull sunset/golden-hour per stage or stop; a "20 min of golden light, 2 musts left" nudge is a moment no competitor offers [SP][CP].
6. **Adopt location-triggered stage surfacing:** geofence per itinerary stop, while-in-use only per [ADR-0007](adr/ADR-0007-while-in-use-location-surfacing.md); SimplistUGC proved the mechanic and Arc's staged guides make it strictly stronger in a travel context [SP].
7. **Position long-term as the execution + provenance layer, not another marketplace:** import any Rexby/PDF/Notion/Maps-list guide and make it runnable ("make this guide capturable"); auto-draft sellable guides from completed trips with "field-verified" badging; if selling, adopt 10–15% take, direct Stripe payouts, $10–50 pricing, and stay creator-aligned where Thatch/TripScout/GuideGeek drifted B2B [IP][SP].
8. **Price at solo-creator impulse level and use the template economy as the acquisition channel:** ~$4–8/mo or modest one-time; make paste-import eat Katie Steckly-style Notion planners cleanly; partner with template creators; ship a shareable Arc field-guide template as the lead-magnet growth loop [SP][CP][IP].

## 8. Sources

Grouped by sweep. URLs verified reachable July 2026; expect rot — re-verify at refresh triggers.

### [SP] shot-planning-apps

- https://www.shotlister.com/ · https://apps.apple.com/us/app/shot-lister/id529436218 · https://profilmmakerapps.com/app/shot-lister/
- https://solubleapps.com/shotlist/ · https://apps.apple.com/us/app/shotlist-movie-shoot-planning/id424885833
- https://www.studiobinder.com/shot-list-storyboard/ · https://www.saasworthy.com/product/studiobinder/pricing
- https://studiovity.com/shotlist-storyboard/ · https://filmustage.com/ · https://www.cadrage.app/ · https://shotdeck.com/welcome/pricing
- https://apps.apple.com/us/app/simplistugc-shot-list-planner/id6759472145
- https://apps.apple.com/us/app/reelshot-pro-vlogging-app/id1449364632 · https://unscriptedphotographers.com/
- https://milanote.com/inspiration/content-creator · https://milanote.com/templates/content-creation/youtube-video-plan · https://www.capterra.com/p/165790/Milanote/
- https://later.com/resources/downloadable/shot-list-template-notion/ · https://www.notion.com/templates/shotlist · https://thomasjfrank.com/templates/notion-video-project-tracker/ · https://katiesteckly.com/travelplanner
- https://lumy.app/ · https://apps.apple.com/us/app/lumy/id908905093 · https://clearoutside.com/forecast/ · https://skiesandscopes.com/astrophotography-apps/
- https://fstoppers.com/landscapes/6-most-valuable-smartphone-apps-landscape-photographers-639816 · https://loadedlandscapes.com/landscape-photography-apps/
- https://www.explorest.com/ · https://apps.apple.com/us/app/explorest-photo-locations/id1227446332 · https://apps.apple.com/us/app/photospot-for-travel-planning/id6461773115
- https://amateurtraveler.com/my-shot-lists-for-travel-iphone-app-for-photographers/
- https://www.rexby.com/ · https://www.rexby.com/blog/rexby-is-the-future-of-travel-guides-for-creators · https://shop.sandbox.thatch.co/italy
- https://wanderlog.com/ · https://www.stippl.io/ · https://scriptation.com/blog/best-apps-for-cinematographers/

### [IP] itinerary-platforms

- https://monkeyeatingmango.com/blog/wanderlog-pricing-2026/ · https://www.aitooldiscovery.com/guides/wanderlog-reddit · https://www.ycombinator.com/companies/wanderlog
- https://www.tripit.com/web/pro/pricing · https://www.pilotplans.com/blog/review-of-tripit
- https://www.stippl.io/creators · https://business.stippl.io/ · https://www.wandrly.app/reviews/stippl · https://shorttermrentalz.com/news/stippl-funding-ai-trip-planning/
- https://news.polarsteps.com/news/polarsteps-summer-2025-release-is-here · https://www.startuprad.io/post/polarsteps-growth-privacy-first-travel-app-at-18m-users-startuprad-io · https://siliconcanals.com/polarsteps-travel-tracking-maximiliano-neustadt-interview/
- https://www.phocuswire.com/mindtrip-thatch-merge-ai-travel-planning-creators · https://mindtrip.ai/thatch/seller · https://techcrunch.com/2021/08/30/thatch-using-3m-round-to-put-travel-creators-on-the-map/
- https://www.businesswire.com/news/home/20251208469469/en/Mindtrip-Unveils-New-AI-Travel-and-Events-Features-Announces-Investments-From-Amex-Ventures-Capital-One-Ventures-and-United-Airlines-Ventures
- https://www.toolify.ai/ai-news/mindtrip-monetize-your-travel-itineraries-for-up-to-10k-monthly-3513038 · https://kayawanderlust.com/from-thatch-to-trash-opinion/
- https://hotspot.earth/alternatives/thatch · https://hotspot.earth/alternatives/rexby
- https://www.rexby.com/ · https://grokipedia.com/page/Rexby · https://www.seedtable.com/funding-round/Rexby_Seed_Round,_November_2025-BZ9JRDY · https://www.rexby.com/worldwildhearts/t/how-to-use-rexby-and-this-travel-guide
- https://solsalute.com/blog/buenos-aires-patagonia-maps/ · https://medium.com/@bembelino22/people-are-earning-thousands-selling-google-maps-lists-and-youre-still-giving-yours-away-for-64fcb3d6eb0c
- https://en.wikipedia.org/wiki/GuideGeek · https://www.prnewswire.com/news-releases/guidegeek-the-free-ai-travel-assistant-from-matador-network-now-available-on-facebook-messenger-302053864.html
- https://tripscout.com/ · https://fullratchet.net/349-the-secrets-behind-building-a-35m-following-why-social-is-the-new-seo-and-how-tripscout-is-creating-the-super-app-for-travel-konrad-waliszewski/
- https://www.travelmassive.com/stay22/creators-2026-report · https://passporterapp.com/en

### [IT] import-and-ai-tech

- https://developer.apple.com/forums/thread/813810 (no public Notes API / TN3132 context)
- https://www.macstories.net/ios/shortcuts-2-2-brings-new-apple-notes-actions-travel-time-enhancements/ · https://support.apple.com/guide/shortcuts/share-actions-apdaf74d75a5/ios
- https://www.macrumors.com/how-to/ios-import-export-markdown-apple-notes/ · https://appleinsider.com/inside/ios-26/tips/how-to-import-and-export-markdown-with-apple-notes-in-ios-26
- https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Share.html
- https://developer.apple.com/videos/play/wwdc2025/244/ · https://developer.apple.com/videos/play/wwdc2025/260/ · https://developer.apple.com/videos/play/wwdc2025/286/
- https://www.appcoda.com/generable/ · https://www.createwithswift.com/exploring-the-foundation-models-framework/
- https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window · https://www.infoq.com/news/2026/03/apple-foundation-models-context/
- https://drobinin.com/consulting/foundation-models-apple-intelligence/putting-apple-foundation-models-in-a-real-app/ · https://support.apple.com/en-us/121115 · https://rudrank.com/exploring-foundation-models-supported-languages-internationalization
- https://machinelearning.apple.com/research/apple-foundation-models-2025-updates · https://developer.apple.com/videos/play/wwdc2026/241/
- https://dev.to/arshtechpro/wwdc-2026-apple-just-opened-the-foundation-models-framework-to-any-llm-provider-5ejn · https://9to5mac.com/2026/06/11/apples-new-foundation-models-explained-on-device-ai-cloud-ai-and-everything-in-between/
- https://openai.com/index/introducing-structured-outputs-in-the-api/ · https://developers.openai.com/api/docs/pricing · https://pricepertoken.com/pricing-page/model/openai-gpt-5-nano · https://pricepertoken.com/pricing-page/model/openai-gpt-5-mini
- https://www.notion.com/templates/category/travel-planner · https://www.notion.com/templates/collections/top-10-free-itinerary-templates-in-notion

### [CP] creator-painpoints

- https://amae.tv/how-to-make-a-travel-video-5-mistakes-travel-vloggers-should-avoid/ · https://lostleblanc.com/blogs/news/how-to-make-a-travel-video
- https://peekatthis.com/creative-travel-filmmaking/ · https://flyingchalks.com/en/study-abroad-blog/travel-tips-12-travel-vlogging-tips-that-will-help-you-make-an-awesome-video-98
- https://blog.explurger.com/best-apps-for-travel-creators-5-tools-youll-actually-use/ · https://medium.com/@oliverastrologo/shooting-without-a-script-c64b0e808e6f
- https://rode.com/en-us/about/news-info/a-guide-to-shooting-solo-when-youre-also-the-talent
- https://www.heylist.com/academy/content-creator-burnout-is-real-and-heres-how-to-come-back-from-it · https://www.entrepreneur.com/living/i-cant-afford-to-take-breaks-content-creators-are/499525
- https://www.quora.com/Do-the-travel-vloggers-really-enjoy-the-trip-like-normal-travellers-as-most-of-the-time-they-are-more-concerned-about-the-shoots-scenes-camera-battery-and-time
- https://www.quora.com/I-am-overwhelmed-with-the-amount-of-travel-video-footage-I-have-How-do-I-edit-it-to-a-nice-short-travel-film
- https://katiesteckly.com/broll · https://izzyvideo.com/b-roll-list/ · https://www.studiobinder.com/templates/shot-list/b-roll-shot-list-template/ · https://www.notion.com/templates/shotlist · https://thomasjfrank.com/templates/notion-video-project-tracker/
- https://www.shotlister.com/ · https://filmlifestyle.com/shot-lister-app-review/ · https://solubleapps.com/shotlist/
- https://medium.com/@aem2317/level-up-your-videos-the-5-shot-rule-7793f6422bef · https://www.tiktok.com/@letscreateonline/video/7253449996626873627
- https://artlist.io/blog/run-and-gun-filming/ · https://www.premiumbeat.com/blog/run-gun-documentary-production-tips/
- https://photoephemeris.com/en/ · https://coffeeinthesun.app/blog/golden-hour-photography-sun-tracking/ · https://www.phototime.app/
- https://reelstrip.com/tiktok-travel-planner · https://triply.au/blog/best-apps-save-travel-places-instagram-tiktok/ · https://www.travelmassive.com/posts/map-your-voyage-852531900 · https://superdirector.app/ideas/tiktok/travel
- https://www.rexby.com/blog/how-top-travel-creators-turn-adventures-into-income · https://mindtrip.ai/thatch/seller · https://techcrunch.com/2021/08/30/thatch-using-3m-round-to-put-travel-creators-on-the-map/
- https://www.the-travel-bunny.com/how-to-make-solo-travel-videos-youtube/ · https://foreverbreak.com/guest/travel-reels/
- https://www.powerbanktests.info/blog/shopping-deals-guides/content-creator-power-banks-real-all-day/ · https://www.anker.com/blogs/power-banks/best-power-bank-for-outdoor-creators
