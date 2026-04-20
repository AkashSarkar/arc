# Shot Planner — Software Requirements & Build Plan (v2)

**Working title:** Frame (placeholder)
**Target user (v1):** Akash, solo creator in Hokkaido shooting Canon R8 + iPhone, producing Instagram carousels and reels.
**Platform:** iOS 26, iPhone only (iPad later), Liquid Glass design language
**Success criterion for v1:** On the next 3 shoots, the app produces a shot list the user actually follows, and catches at least one "shot I would have missed" per trip.
**Non-goal for v1:** public launch, monetization, multi-user features.

---

## 1. Problem Statement

Solo creators arriving at unfamiliar locations experience decision paralysis. They don't know what to shoot, waste time wandering, miss golden hour, and return with disjointed content that doesn't cut into a coherent reel or carousel. Existing tools either catalog spots (PhotoHound), plan astronomical conditions (PhotoPills), or surface inspiration (Pinterest) — none produce a structured, narrative-ordered shot list tied to a specific location, time, and output format.

## 2. Core User Flow

1. User picks a location (search, map pin, or current GPS)
2. User picks a shoot window (date + time range, or "now")
3. User picks an output intent ("Instagram carousel", "90s reel", "single hero shot", "travel blog set")
4. App generates a shot list: 6–12 shots, narratively ordered, each with a reference image, composition note, technical settings hint, and suggested time-of-day
5. In the field: user checks off shots as completed, optionally snaps a reference photo for comparison
6. Post-shoot: user imports the day's photos, app matches them to the shot list, flags what was missed and what's usable

## 3. Feature Scope

### 3.1 Must-have (v1)

**3.1.1 Location input**
- GPS current location (CoreLocation)
- Map pin drop (MapKit)
- Text search (MapKit local search + Wikipedia geosearch API)
- Saved locations (re-plan for a location shot before)

**3.1.2 Location context enrichment**
- POI data from OpenStreetMap (Overpass API) — viewpoints, trails, landmarks, unusual POIs
- Wikipedia + Wikidata lookup for landmark context
- Flickr API search (geo-bounded, sorted by "interestingness") — 30–50 reference images with EXIF
- Sun/moon position calculation (local math, no API) — sunrise, sunset, golden hour, blue hour
- Weather forecast for the shoot window (Open-Meteo API, free, no key)

**3.1.3 Shot list generation**
- Input: location context + shoot window + output intent + style profile
- Output: structured shot list as JSON, rendered as a Liquid Glass card stack
- Each shot card contains:
  - Shot number + narrative role (establishing, detail, subject, transition, hero, closer)
  - Short description
  - Composition note (rule-of-thirds, leading line, negative space, etc.)
  - Suggested focal length range
  - Suggested aperture/shutter hint
  - Suggested time-of-day window (linked to sun calculation)
  - Reference image(s) from Flickr or curated set
  - Rationale ("Opens the carousel; establishes scale")

**3.1.4 In-field tracking**
- Check off completed shots
- Optional: attach a snap from iPhone camera as placeholder
- Progress indicator
- Offline-capable once the shot list is generated (cache everything locally)
- Field mode UI: high-contrast variant that remains readable in direct sunlight (see §4.2)

**3.1.5 Post-shoot review**
- Import the day's photos from Canon Camera Connect's auto-transfer folder or Photos library
- On-device tagging via Apple Foundation Models + Vision framework — classify each photo by likely narrative role
- Match imported photos against planned shot list
- Flag missing shots, duplicate coverage, and photos that didn't fit any planned role
- Export summary ("Got 8 of 10. Missed: boots-in-snow detail, blue-hour closer.")

### 3.2 Should-have (v2)

- Style profile customization (cinematic / minimalism / moody / high-energy viral)
- Multi-day trip planning
- "Similar shot" detection vs. user's last 50 Instagram posts
- Reel story-arc generator (shot list → suggested edit sequence)
- Canon-specific settings suggestions

### 3.3 Won't-have (v1 and likely v2)

- Multi-user, sharing, social
- Cloud sync (iCloud + CloudKit if ever needed)
- Live-preview monitoring
- Real-time AI director in the field
- Android

## 4. System Architecture

```
┌──────────────────────────────────────────────────────────────┐
│         iOS 26 App (Swift 6 / SwiftUI + Liquid Glass)        │
├──────────────────────────────────────────────────────────────┤
│  UI Layer — Liquid Glass card stack, field mode, map views  │
├──────────────────────────────────────────────────────────────┤
│  Domain Layer                                                 │
│  - ShotListGenerator, LocationEnricher, ShotMatcher,         │
│    StyleProfile                                               │
├──────────────────────────────────────────────────────────────┤
│  Data / Service Layer                                         │
│  - LocalCache (SwiftData)                                     │
│  - APIClients: OSM Overpass, Wikipedia, Flickr, Open-Meteo   │
│  - LLMClient (OpenAI-compatible, configurable base URL)      │
│     - dev: LM Studio at http://<mac-ip>:1234/v1              │
│     - prod: OpenAI, Claude (OAI-compat), Gemini (OAI-compat) │
│  - OnDeviceInference: FoundationModels + Vision              │
│     - photo tagging, role classification, matching           │
└──────────────────────────────────────────────────────────────┘
```

### 4.1 LLM provider strategy

The LLMClient speaks **OpenAI Chat Completions format** as its contract. Every supported backend either speaks it natively or has a compatibility shim:

| Provider | Endpoint | Notes |
|----------|----------|-------|
| LM Studio (local) | `http://<mac-ip>:1234/v1/chat/completions` | Native OpenAI-compatible. Dev default. |
| OpenAI | `https://api.openai.com/v1/chat/completions` | Native. |
| Anthropic Claude | `https://api.anthropic.com/v1/chat/completions` | OpenAI-compatible endpoint available. Or swap to native `/v1/messages` via adapter. |
| Google Gemini | `https://generativelanguage.googleapis.com/v1beta/openai/chat/completions` | OpenAI-compatible mode. |
| Any local runner (Ollama, llama.cpp server) | Configurable | All speak OpenAI-compatible. |

Configuration lives in app Settings:

```swift
struct LLMConfig: Codable {
    var baseURL: URL           // e.g., http://192.168.1.42:1234/v1
    var apiKey: String?        // nil for LM Studio, required for cloud
    var modelName: String      // e.g., "qwen2.5-72b-instruct", "claude-opus-4-7"
    var useStructuredOutput: Bool
    var timeoutSeconds: Int    // local models need longer
}
```

Store configs as named profiles: "LM Studio - Qwen 72B", "Claude Haiku", "Local Llama 3.3". Switch via Settings. No code changes to swap providers.

**Structured output:**
- Use `response_format: { type: "json_object" }` — works in LM Studio (model-dependent), OpenAI, Gemini OAI-compat. Claude needs tool use or explicit prompt instruction.
- Always pair JSON mode with explicit "respond only with JSON matching this schema" in the prompt. Local models often produce malformed output even with JSON mode.
- Parse defensively. Wrap in a retry loop with one re-prompt on parse failure before surfacing an error.

### 4.2 Liquid Glass UI considerations

Liquid Glass is the default iOS 26 look. Use it, with two specific constraints for this app:

- **Shot cards in Plan view:** standard Liquid Glass with layered depth works well. Reference image behind, glass surface carrying shot metadata on top. Reads well indoors.
- **Field view (outside in sunlight):** Liquid Glass translucency fails in direct Hokkaido sun. Provide a "Field Mode" toggle that switches to solid high-contrast surfaces with oversized tap targets. Liquid Glass is for planning; opaque high-contrast is for the field. Not negotiable given your actual shooting conditions.
- **Test early, test outside.** SwiftUI Previews lie about outdoor readability. Take the device outside during weekend 4 and look at it. Adjust.

### 4.3 Network configuration for LM Studio dev workflow

Setup steps that will bite you on Saturday morning if skipped:

1. **Info.plist** — add `NSAppTransportSecurity` with `NSAllowsLocalNetworking = true`. HTTP requests to RFC1918 addresses bypass ATS; cloud HTTPS continues to work normally.
2. **Info.plist** — add `NSLocalNetworkUsageDescription` with a user-facing string. iOS will prompt on first request to a LAN address.
3. **LM Studio server config** — bind to `0.0.0.0` not `127.0.0.1` so the iPhone on the same LAN can reach it. Port 1234 by default.
4. **iPhone and Mac on the same WiFi network.** Obvious but easy to forget when using cellular.
5. **Simulator** — can hit `http://localhost:1234` directly, no local network permission needed. Covers 90% of dev work; physical device test each weekend before merging.

### 4.4 On-device models (iOS 26 native)

Apple Foundation Models framework (iOS 26) provides an on-device model via native Swift API. Use it for:
- **Photo tagging** (weekend 5): given a photo + list of planned shot descriptions, return the best-matching shot role. Small-model territory, fast, free, private.
- **NOT for planning.** The on-device model will produce generic shot lists. Planning stays on the cloud / LM Studio path.

Apple Vision framework remains the workhorse for classical CV tasks (horizon detection, saliency, classification). Use Vision for what it's good at; use Foundation Models for reasoning glue on top.

## 5. Data Model (SwiftData, iOS 26)

```swift
@Model final class Location {
    var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var elevation: Double?
    var poiContext: String  // cached JSON from enrichment
    var lastEnrichedAt: Date
    @Relationship(deleteRule: .cascade) var shotPlans: [ShotPlan]
}

@Model final class ShotPlan {
    var id: UUID
    var location: Location
    var createdAt: Date
    var shootWindowStart: Date
    var shootWindowEnd: Date
    var outputIntent: String  // raw enum value
    var styleProfileID: UUID
    var llmProfileName: String  // which LLM config generated this
    var llmModelName: String    // specific model used
    @Relationship(deleteRule: .cascade) var shots: [PlannedShot]
}

@Model final class PlannedShot {
    var id: UUID
    var plan: ShotPlan
    var sequenceNumber: Int
    var narrativeRole: String
    var shotDescription: String
    var compositionNote: String
    var focalLengthMin: Int
    var focalLengthMax: Int
    var settingsHint: String
    var suggestedWindowStart: Date?
    var suggestedWindowEnd: Date?
    var referenceImageURLs: [URL]
    var rationale: String
    var completed: Bool
    var completedAt: Date?
    var matchedPhotoIdentifier: String?  // PHAsset localIdentifier
}

@Model final class StyleProfile {
    var id: UUID
    var name: String
    var systemPrompt: String
    var isDefault: Bool
}

@Model final class LLMProfile {
    var id: UUID
    var name: String
    var baseURL: URL
    var modelName: String
    var apiKeyKeychainRef: String?  // key stored in Keychain, ref stored here
    var useStructuredOutput: Bool
    var timeoutSeconds: Int
}
```

Tracking which LLM profile generated which plan gives you A/B telemetry for free. Compare the same location planned by Qwen 72B local vs. Claude vs. Gemini — instantly visible.

## 6. The Planning Prompt (core IP)

```
SYSTEM:
You are a cinematographer and photo director planning a shoot.
You produce structured, narratively-ordered shot lists optimized for {outputIntent}.
Style: {styleProfile.systemPrompt}
Output MUST be a valid JSON object matching this schema (no prose, no markdown):
{
  "shots": [
    {
      "sequence": int,
      "role": "establishing|detail|subject|transition|hero|closer",
      "description": string,
      "composition_note": string,
      "focal_length_min": int,
      "focal_length_max": int,
      "settings_hint": string,
      "time_window_label": string,
      "rationale": string
    }
  ]
}

USER:
Location: {location.name} at {coordinate}
POI context: {poiContext}
Reference imagery (Flickr, most-interesting, last 12 months):
  {top 20 photos with titles, tags, EXIF focal length, capture time}
Shoot window: {start} to {end}
Sun events: sunrise {t}, golden hour {t-t}, sunset {t}, blue hour {t-t}
Weather forecast: {forecast summary}
Output intent: {carousel | reel | hero | blogSet}

Generate 8 shots (6 for hero, 12 for blogSet).
Each shot must have a clear narrative role and tie to the location's
distinctive features. Do not generate generic shots; reference specific
elements from the POI context or reference imagery.
```

Build a small evaluation harness: 5 locations you know well (Jozankei, Otaru canal, Asahidake, Shiretoko, Sapporo TV Tower), run the prompt, score each output manually on 1–5 for: (a) specificity to location, (b) narrative coherence, (c) temporal sensibility, (d) actionability. Run against each LLM profile. That matrix tells you which model is worth using in production. That's the real v1 milestone — everything after is UI around validated output.

## 7. Build Plan (6 weekends)

**Weekend 1 — Foundation**
- [ ] New SwiftUI project, Swift 6, iOS 26 minimum, Liquid Glass enabled
- [ ] Set up SwiftData models from section 5
- [ ] Location picker (GPS + map pin + MapKit search)
- [ ] Empty shell screens: LocationList, LocationDetail, PlanView, FieldView, ReviewView
- [ ] Info.plist: local network + ATS exception
- Deliverable: create, name, persist a location. No AI yet.

**Weekend 2 — Enrichment pipeline + LLM client**
- [ ] API clients: Overpass, Wikipedia, Flickr, Open-Meteo
- [ ] Sun/moon calculation (NOAA algorithm, public domain, pure math)
- [ ] LocationEnricher: Location → structured context bundle → cache
- [ ] LLMClient with OpenAI-compatible contract
- [ ] Settings UI for LLMProfile CRUD (add, edit, select active)
- [ ] Keychain integration for API keys
- Deliverable: enrich a location, dump JSON; hit LM Studio from simulator and get a chat completion back. No shot list yet.

**Weekend 3 — Prompt engineering + generation** ← the make-or-break weekend
- [ ] ShotListGenerator: enriched context + prompt + LLMClient → PlannedShot array
- [ ] Evaluation harness: 5 locations × N LLM profiles → scored JSON outputs
- [ ] Iterate prompt until scores are consistently 4+
- [ ] Do not rush this weekend. This is where the product lives or dies.
- Deliverable: real shot lists for 5 locations, reviewed against your own taste

**Weekend 4 — Shot list UI + field mode**
- [ ] Liquid Glass card stack (Plan view)
- [ ] Field Mode (high-contrast opaque variant)
- [ ] Completion toggling, progress indicator
- [ ] Offline caching (download all reference images on plan generation)
- [ ] **Physical device, outside, in sunlight. Look at it. Fix what breaks.**
- Deliverable: generate a plan, open offline, check off shots in the field

**Weekend 5 — Review pipeline**
- [ ] PhotoKit: read day's photos
- [ ] Apple Vision + Foundation Models for on-device shot-role tagging
- [ ] Matching algorithm: planned shot × imported photos → best match
- [ ] Review screen: got / missed / unmatched
- Deliverable: post-shoot view showing coverage

**Weekend 6 — Dogfood and iterate**
- [ ] 2 actual shoots with the app
- [ ] Note every friction point
- [ ] Fix top 3
- [ ] Decide: ship, keep personal, or kill

## 8. Cost and Performance Reality Check

**Dev (LM Studio, Mac-dependent):**
- Free. Pay in fan noise and RAM.
- Speed varies by model and hardware:
  - Qwen 2.5 7B Q4 on M2 16GB: ~30 tok/s, shot list in ~15s
  - Qwen 2.5 72B Q4 on M3 Max 64GB: ~10 tok/s, shot list in ~60s
  - Llama 3.3 70B Q4 on M3 Max 64GB: similar
- If iteration feels painfully slow, use cloud Haiku for prompt iteration and LM Studio for acceptance testing only.

**Prod (cloud, if shipped):**
- Claude Haiku: ~$0.003/shot list. 50 plans/year personal = $0.15. 100 users × 10/month = ~$36/month.
- GPT-4o-mini: similar.
- Gemini 2.0 Flash: cheaper, free tier available.

**Other APIs:**
- Open-Meteo: free, no key, no limit
- Wikipedia/Wikidata: free, no key
- Overpass: free, rate-limited, cache aggressively
- Flickr: free, 3600 req/hour with a key
- Apple Foundation Models + Vision: free, on-device

Set a $10/month cap on any cloud provider you use.

## 9. Risks and Mitigations

- **Prompt quality is the product.** Mitigation: §6 evaluation harness in weekend 3 before committing to UI.
- **Local-only dev hides cloud-model ceiling.** Mitigation: run the evaluation harness against one frontier model (trial credits suffice) so you know the quality ceiling you're benchmarking against.
- **LM Studio model choice wrong.** A 7B model will make the app feel broken. Use the largest quant your Mac can run at 5+ tok/s.
- **Liquid Glass in sunlight is unreadable.** Mitigation: §4.2 Field Mode, tested outdoors before weekend 4 ends.
- **Flickr sparse for obscure locations.** Mitigation: Unsplash fallback, accept weaker output for remote spots.
- **Local network permission confuses users if shipped publicly.** Mitigation: LM Studio path is dev-only. Remove the dev profile from shipped build via compile-time flag.
- **You abandon the project.** Highest-probability risk. Mitigation: 6 Saturdays on calendar, public commitment, or don't start.

## 10. Out of Scope

- Marketing
- Android
- Collaborative planning
- Auto-publishing
- Video editing

---

## Decisions required before Weekend 1

1. **Mac specs and LM Studio model.** What Mac are you on? Pick a model that gives you 5+ tok/s. Qwen 2.5 Instruct at the largest quant you can run is the safe pick.
2. **Evaluation-harness cloud provider.** Claude Haiku, Gemini Flash (free tier), or GPT-4o-mini? Pick one, get a key, stash it in Keychain on first launch.
3. **Project name.** Placeholder expiring by weekend 1.
4. **Hard v1 dogfood deadline.** 6 Saturday dates on the calendar. Non-negotiable.
