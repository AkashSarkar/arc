# ADR-0001: Tiered Import Pipeline (T0-T3)

Status: Accepted
Date: 2026-07-06

## Context

Import is the front door of the core loop: paste an Apple Notes / ChatGPT-markdown trip plan, get a staged field guide. The uncommitted prototype couples parsing to a cloud call (`Arc/Features/Planning/Domain/ImportedPlanGenerator.swift` calls the OpenAI-compatible service and falls back to `ImportedPlanParser.swift`), which makes the primary path online-dependent, non-deterministic, and untestable — unacceptable for an offline-first field app. iOS 26 ships on-device Apple Foundation Models with `@Generable` constrained decoding, which changes the cost/privacy calculus for the middle tier.

## Decision

Build import as a tiered pipeline. Every tier targets the same output contract: `ArcPlanDocument` ([ADR-0004](ADR-0004-arcguide-document-interchange.md)).

| Tier | Engine | Role | Constraints |
|---|---|---|---|
| T0 | Deterministic heuristics | **Always runs.** Universal fallback + per-day chunker; guarantees the Arc-Flavored Plan (AFP) conventions parse. | Offline, synchronous, fully unit-testable. The guaranteed floor. |
| T1 | On-device Apple Foundation Models `@Generable` | Default cleanup/enrichment of T0 output. Schema-safe constrained decoding, zero marginal cost, private. | Availability-gated via `SystemLanguageModel`. 4,096-token window: chunk per detected day (T0 provides day boundaries). Prewarm on the import screen. Any guardrail violation falls back to T0 output silently. |
| T2 | Existing OpenAI-compatible cloud path | Optional, explicit user opt-in per Settings. | Never a dependency; absence must not degrade T0/T1. Reuses `OpenAICompatibleAIService`; no new endpoints. |
| T3 | `PrivateCloudComputeLanguageModel` (iOS 27, 32K context) | Future upgrade note only. Do not build, stub, or design around it now. | Revisit when iOS 27 ships. |

Do NOT add any new third-party cloud infrastructure for import. Do NOT let any tier above T0 become required for a successful import.

## Consequences

**Positive:**
- Import works offline, deterministically, on day one; T1/T2 only improve quality, never gate it.
- T1 gives near-cloud parsing quality with zero cost and zero data egress, matching the privacy posture in [../04-architecture.md](../04-architecture.md).
- One output contract means the pipeline is written once; tiers are swappable stages, individually testable.

**Negative:**
- Parsing quality is bounded by corpus-driven iteration on T0 heuristics and T1 prompts/schemas (see [../09-quality.md](../09-quality.md)), NOT by swapping in bigger models. Improving import means growing and re-running the real-plan corpus.
- Per-day chunking for T1 means cross-day inference (e.g. a stage spanning midnight) is out of scope for on-device cleanup.
- Maintaining T0 forever is a permanent cost; it can never be deleted.

**Follow-ups:**
- P1: implement the tier chain against `ArcPlanDocument`; specify AFP conventions and tier behavior in [../06-import-spec.md](../06-import-spec.md).
- P1: seed the import corpus from the owner's real Apple Notes / ChatGPT plans ([../09-quality.md](../09-quality.md)).
- iOS 27: write a superseding or extending ADR if T3 is adopted.

## Links

- [../06-import-spec.md](../06-import-spec.md) — owner doc for tier behavior and AFP
- [../09-quality.md](../09-quality.md) — corpus-driven parser iteration
- [ADR-0004-arcguide-document-interchange.md](ADR-0004-arcguide-document-interchange.md) — the output contract
- [../08-roadmap.md](../08-roadmap.md) — P1 scope
