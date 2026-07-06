# ADR-0005: Backend Deferred; CloudKit First When Gated

Status: Accepted
Date: 2026-07-06

## Context

Arc is a solo-developer business asset with zero off-app infrastructure today: the YouTube channel is pre-launch, there is no email list, no server, no ops budget, and no time budget for ops. Every backend decision made now would be speculation about an audience that does not exist yet. Phases gate on channel milestones, never calendar dates, and the gates table lives only in [../02-business.md](../02-business.md).

## Decision

Build NO backend of any kind — no server, no database, no serverless functions, no third-party BaaS — until gates G3 (audience signal) AND G4 (willingness-to-pay) are met per [../02-business.md](../02-business.md). Until then the app is fully on-device; the only network calls are the existing enrichment APIs and the opt-in T2 cloud parse ([ADR-0001](ADR-0001-tiered-import.md)).

When the gates are met, evaluate CloudKit FIRST as the default candidate. Decision inputs, recorded now so this is not relitigated from scratch:

| Input | Weight for CloudKit |
|---|---|
| Zero ops / zero hosting cost | Strong — solo developer, 5-10 year horizon, no ops time |
| Native auth (Apple ID) + SwiftData/CloudKit sync | Strong — no account system to build or secure |
| `CKShare` for sharing `.arcguide` payloads | Moderate — covers device-to-device and small-circle sharing |
| Privacy posture (no Arc-run server holding user data) | Strong — consistent with on-device T1 and no-analytics stance |
| Web-side buyers (people without the app buying a guide from a link) | **Against** — CloudKit Web Services is a poor storefront |
| Payment flexibility (web checkout, [ADR-0006](ADR-0006-email-capture-and-paid-guides.md)) | **Against** — payments cannot run through CloudKit |

Recorded counterweight: guide DISTRIBUTION to web-side buyers and payment flexibility may force a thin custom API (stateless, serving `ArcGuideDocument` payloads and taking payments) even if personal-data sync stays on CloudKit. That split — CloudKit for sync, thin API for commerce — is the expected end-state; treat it as the hypothesis to confirm or reject at the gate.

## Consequences

**Positive:**
- Zero infra cost and zero ops surface through P0-P4; all engineering time goes to the core loop.
- The decision inputs above turn the future backend choice into a bounded evaluation, not a blank-page debate.
- Email capture proceeds anyway via the web preview page + an off-the-shelf email service ([ADR-0006](ADR-0006-email-capture-and-paid-guides.md)); a mailing-list provider is not "a backend" under this ADR.

**Negative:**
- No cross-device sync and no cloud backup until the gates are met; the owner's data lives on one iPhone (mitigated by `.arcguide` export, [ADR-0004](ADR-0004-arcguide-document-interchange.md)).
- If G3/G4 arrive quickly, backend work starts from zero at exactly the moment audience momentum wants features.
- CloudKit-first, if adopted, deepens Apple platform lock-in.

**Follow-ups:**
- P5 gate: write the superseding/refining ADR choosing CloudKit, thin API, or the split, against then-current facts.
- Now: keep `Arc/Core/Documents/` SwiftData-free so document payloads can be served from any future backend unchanged.

## Links

- [../02-business.md](../02-business.md) — gates G1-G4 (single source of truth)
- [../08-roadmap.md](../08-roadmap.md) — P5 Platform scope
- [ADR-0004-arcguide-document-interchange.md](ADR-0004-arcguide-document-interchange.md), [ADR-0006-email-capture-and-paid-guides.md](ADR-0006-email-capture-and-paid-guides.md)
