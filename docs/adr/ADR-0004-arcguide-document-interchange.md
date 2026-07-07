# ADR-0004: ArcPlanDocument / ArcGuideDocument Interchange Format

Status: Accepted
Date: 2026-07-06

## Context

Four features need the same serialized shape: import (every parser tier must emit one stable target so the pipeline is written once — [ADR-0001](ADR-0001-tiered-import.md)), export/review, sharing between devices, and eventually published guides with a web preview ([ADR-0006](ADR-0006-email-capture-and-paid-guides.md)). Today export is a plain-text `ShareLink` in `CompletedShootView` and import targets ad-hoc draft structs. Defining the document before storage v2 lets the import pipeline and the schema rebuild both code against a fixed contract instead of each other.

## Decision

Define, in P1 and BEFORE schema v2 lands, a single versioned Codable JSON document format:

| Property | Value |
|---|---|
| Types | `ArcPlanDocument` / `ArcGuideDocument` — ONE JSON schema, discriminated by `kind` |
| `kind` | `plan` (pre/mid-trip: importable, executable) \| `guide` (post-trip: field-verified, publishable) |
| Versioning | Integer `schemaVersion`. Ship an upgrade decoder for version N-1 at all times; decoding N-2 or older may fail with a clear error. |
| UTType | `com.arc.guide` |
| File extension | `.arcguide` |
| Home | `Arc/Core/Documents/` — this folder MUST NEVER import SwiftData (enforce by review; it depends on Foundation only). |
| Media | Excluded from documents by default. Documents carry text, structure, geo anchors, and execution metadata; photos/video stay on-device. |

Rules: all import tiers emit `ArcPlanDocument`; all exports and shares serialize through this format; mapping between documents and SwiftData entities lives in feature code, never in `Arc/Core/Documents/`; the payload stays neutral to any future paid/free distinction ([ADR-0006](ADR-0006-email-capture-and-paid-guides.md)).

## Consequences

**Positive:**
- One contract decouples the parser tiers, schema v2, export, and the future web preview; each can change behind it independently.
- `kind: guide` is the concrete artifact of the long-term positioning — the execution + provenance layer producing field-verified guides — without building any marketplace.
- The SwiftData-free `Arc/Core/Documents/` module can be reused verbatim server- or web-side later.
- Gives [ADR-0003](ADR-0003-store-reset-pre-ship.md) its courtesy-export target for free.

**Negative:**
- N-1 upgrade decoders are a permanent maintenance tax on every `schemaVersion` bump; version bumps must be rare and deliberate.
- Excluding media means a shared `.arcguide` is not a complete backup; anyone expecting photos in the file will be disappointed (document this in export UI copy).
- A pre-storage contract risks mismatch with schema v2; mitigated by [../05-data-model.md](../05-data-model.md) and [../06-import-spec.md](../06-import-spec.md) being written against the same field list.

**Follow-ups:**
- P1: implement `Arc/Core/Documents/` + declare `com.arc.guide` / `.arcguide` in the app target; specify the field-level schema in [../05-data-model.md](../05-data-model.md).
- P2: schema v2 ↔ document mapping in feature code ([ADR-0002](ADR-0002-schema-v2-rebuild.md)).
- P4: `kind: guide` export + share preview path ([../08-roadmap.md](../08-roadmap.md)).

## Links

- [../05-data-model.md](../05-data-model.md) — field-level document schema
- [../06-import-spec.md](../06-import-spec.md) — tier behavior / AFP conventions
- [../04-architecture.md](../04-architecture.md) — module boundary rules
- [ADR-0001-tiered-import.md](ADR-0001-tiered-import.md), [ADR-0002-schema-v2-rebuild.md](ADR-0002-schema-v2-rebuild.md), [ADR-0003-store-reset-pre-ship.md](ADR-0003-store-reset-pre-ship.md), [ADR-0006-email-capture-and-paid-guides.md](ADR-0006-email-capture-and-paid-guides.md)
