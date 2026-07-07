# 02 — Business Model & Milestone Gates

> **Agent Brief** — Status: Current | Applies to: All phases (gates control phase entry) | Owner doc for: business context, flywheel, funnel mechanics, off-app stack, milestone gates G1–G4, monetization ladder
> Read [docs/00-index.md](00-index.md) first. Behavioral rules: /AGENTS.md (wins on conduct). Current build phase: see [docs/08-roadmap.md](08-roadmap.md).
> Code pointers verified against ux-redesign @ abce4bc + uncommitted field-guide work (2026-07-06). Re-verify line numbers before editing.

This document is the **single source of truth for milestone gates G1–G4**. No other doc may redefine a gate; they must link here. Phases in [docs/08-roadmap.md](08-roadmap.md) unlock on gates, never on calendar dates.

## 1. Context

- The business is **travel content creation** on a 5–10 year horizon. YouTube is the primary channel and it is **pre-launch today** (no videos published as of 2026-07-06).
- Arc is a **business asset**, not a startup. Its job is to (a) make the owner's capture-execution loop reliable, and (b) later convert viewers into an owned audience (email list) and paying guide buyers.
- **Near-term the only user is the owner.** Every product decision before G3 optimizes for one solo travel content creator on one iPhone. Do not build for hypothetical users.
- Priority order for the asset: **email list first** (free itinerary per video, gated on an email address), **paid guides later**. See the monetization ladder in section 6.
- **No off-app infrastructure exists yet** — no domain in service of Arc, no ESP account, no landing page, no backend. Section 4 documents what will exist and when; nothing in it is built before its gate.

## 2. Flywheel

```
publish video (YouTube)
      │
      ▼
free itinerary offer in the video description
      │
      ▼
static web map preview of the guide (.arcguide rendered client-side)
      │
      ▼
email capture (ESP-gated download)
      │
      ▼
guide opens in Arc as a runnable trip (deep link / QR / .arcguide file)
      │
      ▼
execution telemetry + field-verified provenance
(captured/skipped/noted per stop, timestamps, field notes)
      │
      ▼
better guides + better videos ──────► back to "publish video"
```

Each loop compounds: executed trips produce provably field-verified guides ([docs/03-market-research.md](03-market-research.md) section on provenance), which make the free-itinerary offer stronger, which grows the list, which later becomes the paid-guide audience.

## 3. Funnel mechanics (per video)

| Step | Mechanism | Notes |
|---|---|---|
| 1. Offer | Itinerary link in the YouTube description (and pinned comment) | One guide per video. Copy pattern: "Get the exact shoot-ready itinerary from this video, free." |
| 2. Preview | Static web page renders the `.arcguide` JSON client-side: map + stop list | No server-side app. The page is static hosting + JS that parses the ArcGuideDocument (see [ADR-0004](adr/ADR-0004-arcguide-document-interchange.md)). Preview shows enough to want it, not the full guide. |
| 3. Gate | Email form via an ESP; ESP delivers the guide download link | ESP owns the form, list, and delivery email. No custom form backend. |
| 4. Open | Deep link / QR code opens the guide in Arc as a runnable trip | For non-Arc users the `.arcguide` file is still a readable JSON artifact; the page can also render it fully post-gate. Arc install is optional at this stage — the email is the asset. |

Constraints:

- The preview page must work with **zero backend**: fetch a static `.arcguide` file, render map + stops in the browser. This is why plan and guide share one JSON schema ([ADR-0004](adr/ADR-0004-arcguide-document-interchange.md)) and why no backend exists ([ADR-0005](adr/ADR-0005-backend-deferred-cloudkit-first.md)).
- Everything in this section is **documented now, built only in P4 after G2 passes** (see gates table).

## 4. Minimal off-app stack

Documented now so P4 work has a target; **nothing here is built before its gate**.

| Component | What it is | Build trigger | Explicit constraints |
|---|---|---|---|
| Static landing + guide-preview page | Boring static hosting (e.g. GitHub Pages / Cloudflare Pages class). One landing page + one preview page template that renders `.arcguide` JSON client-side | P4 (after G2) | No custom backend, no server-side rendering, no database |
| ESP (email service provider) | One provider in the Kit / Beehiiv class: form, list, automated guide-delivery email | Pick at G2, in use by P4 | One provider only. No newsletter automation beyond the delivery email before G3 |
| Link-in-bio | Single link routing to landing page / latest guide offer | G2 (channel live) | Use an existing service or a page on the static site; do not build one |

Explicitly **not** in the stack before gates: custom backend, web store / checkout, payment processing, newsletter automation, analytics infrastructure beyond what the ESP and YouTube provide. Backend deferral rationale: [ADR-0005](adr/ADR-0005-backend-deferred-cloudkit-first.md). Payments open question (IAP vs web checkout): [ADR-0006](adr/ADR-0006-email-capture-and-paid-guides.md).

## 5. Milestone gates (single source of truth)

Gates are **evidence-based, never date-based**. A phase does not start until its gate has passed. When citing a gate elsewhere, link to this table — do not restate definitions.

| Gate | Definition | Evidence required | What it unlocks |
|---|---|---|---|
| **G1 — dogfood proven** | >=3 real trips fully executed through Arc: imported plan → staged field guide → in-field execution → completed review, end to end, no fallback to Apple Notes mid-trip | 3 completed trips in Arc with execution data (captured/skipped/noted items, field notes); owner's post-trip verdict that Arc was the primary field tool for each | **P3** (Field ergonomics v2 + review/export v2) |
| **G2 — channel live** | First videos published on the YouTube channel + the free-itinerary offer tested manually (link in description, hand-assembled delivery — no automation required) | Published videos publicly visible; at least one manual itinerary request fulfilled end to end | **P4** (Guide export + share preview + email capture); ESP selection |
| **G3 — audience signal** | ~100 emails captured OR recurring unprompted itinerary requests (comments/DMs asking for itineraries across multiple videos) | ESP list count, or a logged pattern of repeat requests | **P5 build consideration** (platform work may be scoped, not necessarily built; P5 docs-only work may run parallel with P4 — see [docs/08-roadmap.md](08-roadmap.md)) |
| **G4 — willingness-to-pay** | Recurring purchase signals: people repeatedly attempting or asking to pay for guides (pre-orders, "take my money" replies, manual sales) | Actual money or repeated concrete purchase intent — not likes, not poll answers | Payments / platform build (paid guides; resolves [ADR-0006](adr/ADR-0006-email-capture-and-paid-guides.md) open question) |

Rules for agents:

- If a task depends on a gate that has not passed, the task is out of scope. Say so and stop.
- Gate status is recorded in [docs/08-roadmap.md](08-roadmap.md) (current-phase section); the definitions live only here.
- Do not soften a gate to unblock work. Building ahead of evidence is the failure mode this table exists to prevent.

## 6. Monetization ladder

Ordered; each rung requires the prior rung's gate. Pricing bands from July 2026 market research ([docs/03-market-research.md](03-market-research.md)).

| Rung | Offer | Price | Gate | Notes |
|---|---|---|---|---|
| 1 | Free guide per video, gated on email | $0 (email) | G2 to launch, G3 proves it | The list is the product. Highest-leverage asset for a 5–10 yr channel |
| 2 | Paid guides (owner-authored, field-verified) | $10–50 one-time per guide | G4 | Observed market band for creator guides. **Buyer app stays free** — no buyer subscription, ever. IAP vs web checkout is an open question in [ADR-0006](adr/ADR-0006-email-capture-and-paid-guides.md) |
| 3 | Far-future: other creators sell field-verified guides through Arc | 10–15% platform take, direct payouts to creators | Beyond G4; not scheduled | Market anchor: Hotspot at 10% flat, Thatch was 10%; Rexby's 20–50% marketplace take is resented by creators. Arc stays at the creator-aligned end or does not do this at all |

Rung 3 is a direction, not a commitment. Arc's long-term position is **execution + provenance layer** for the guide economy, not another marketplace ([docs/03-market-research.md](03-market-research.md)).

## 7. What we deliberately do NOT do

| Non-goal | Why |
|---|---|
| Paid marketplace first | Rexby/Mindtrip own discovery marketplaces with multi-year head starts; competing there burns years before the channel exists. Arc's wedge is execution, not discovery |
| Buyer subscriptions | The buyer app stays free to maximize guide distribution (Polarsteps pattern). Charging buyers a subscription kills the funnel at step 4 |
| B2B / DMO drift | The documented failure pattern of this exact space: Thatch was absorbed into Mindtrip (creators became traffic acquisition for an AI planner, "From Thatch to Trash" backlash); TripScout abandoned consumer guides to become a DMO agency. Chasing tourism-board money orphans creators. Details: [docs/03-market-research.md](03-market-research.md) |
| Custom backend / store / automation before gates | See section 4 and [ADR-0005](adr/ADR-0005-backend-deferred-cloudkit-first.md). Infrastructure without an audience is pure carrying cost |
| Calendar-driven roadmap | Phases gate on G1–G4 evidence only. A date on a phase is a bug in the doc that contains it |

## Cross-references

- Phase definitions and current phase: [docs/08-roadmap.md](08-roadmap.md)
- Competitive landscape, pricing evidence, cautionary tales: [docs/03-market-research.md](03-market-research.md)
- `.arcguide` interchange format: [ADR-0004](adr/ADR-0004-arcguide-document-interchange.md)
- Backend deferral: [ADR-0005](adr/ADR-0005-backend-deferred-cloudkit-first.md)
- Email capture + paid guides decision record: [ADR-0006](adr/ADR-0006-email-capture-and-paid-guides.md)
