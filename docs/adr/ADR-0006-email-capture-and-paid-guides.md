# ADR-0006: Email Capture Off-App; Paid-Guide Path Open

Status: Accepted
Date: 2026-07-06

## Context

The business model is email list first (free itinerary per video, gated on email), paid guides later ([../02-business.md](../02-business.md)). App Store rules make WHERE these transactions happen architecturally significant: digital content sold or unlocked inside the app generally requires In-App Purchase with a 15-30% commission, while transactions completed entirely on the web with the resulting content consumed on the web do not. This ADR fixes the email-capture path now and deliberately leaves the paid path open.

## Decision

**Email capture (decided):** capture emails on the WEB guide-preview page (the P4 share preview), not inside the app. The funnel is: YouTube video → link → web preview of the `.arcguide`-backed itinerary → email gate → full free itinerary. Because the exchange (email for free content) happens entirely off-app, it carries no IAP implication. Do not build an email-gate UI inside the iOS app.

**Paid guides (STATUS: OPEN — do not implement, do not foreclose):** the choice of paid path is explicitly unresolved and MUST be resolved at the P5 gate against then-current App Store rules, not today's. Alternatives on record:

| Option | Mechanics | Risk / cost |
|---|---|---|
| In-app IAP | Buy guide inside Arc, unlock in-app | 15-30% commission; simplest compliance |
| Rexby-pattern web checkout + in-app redemption | Buy on the web, redeem via code/account in-app | Commission-free; redemption UX friction; rules on "reader"-style flows shift |
| US external-link entitlement (post-2025 landscape) | In-app link out to web checkout | US-only, litigation-dependent, terms in flux as of mid-2026 |

Payload neutrality (decided): `ArcPlanDocument`/`ArcGuideDocument` ([ADR-0004](ADR-0004-arcguide-document-interchange.md)) stays identical for free and paid guides — no DRM fields, no entitlement flags, no paid-only sections in the schema. Access control, if any, lives entirely in the distribution layer ([ADR-0005](ADR-0005-backend-deferred-cloudkit-first.md)), so no architecture bet rides on the open question.

## Consequences

**Positive:**
- Email capture can ship in P4 with only a static-ish web page and an off-the-shelf email provider — no backend, no App Review exposure.
- Deferring the paid path avoids betting on App Store rules that have changed repeatedly since 2025 and will change again before G4.
- Payload neutrality means whichever paid path wins, the document format and app code do not change.

**Negative:**
- An OPEN decision is a standing hazard: an agent building P4/P5 features must not quietly assume IAP or web checkout. Anything that would foreclose an option (e.g. baking entitlements into the document schema) violates this ADR.
- The web preview page becomes a real dependency of the business funnel despite living outside the repo; it needs an owner and a checklist entry in [../08-roadmap.md](../08-roadmap.md).
- Rexby-pattern redemption, if chosen later, will need account/redemption plumbing that nothing in P0-P4 builds toward.

**Follow-ups:**
- P4: build the web preview + email gate; define the preview's data source (static export of `ArcGuideDocument`).
- P5 gate: write the superseding ADR choosing the paid path against then-current rules; re-verify the external-link entitlement status at that date.

## Links

- [../02-business.md](../02-business.md) — funnel, gates G3/G4
- [../03-market-research.md](../03-market-research.md) — Rexby pattern, guide-economy positioning
- [ADR-0004-arcguide-document-interchange.md](ADR-0004-arcguide-document-interchange.md), [ADR-0005-backend-deferred-cloudkit-first.md](ADR-0005-backend-deferred-cloudkit-first.md)
