# Arc Documentation Index

> **Agent Brief** — Status: Current | Applies to: All phases | Owner doc for: doc set structure, precedence, Agent Brief spec, glossary
> Read this doc first. Behavioral rules: /AGENTS.md (wins on conduct). Current build phase: see [docs/08-roadmap.md](08-roadmap.md).
> Code pointers verified against `task-owner-mvp-through-p4` after owner-test MVP implementation (2026-07-07). Re-verify line numbers before editing.

## 1. Purpose

This doc set is written for AI coding agents implementing Arc phase by phase, and for the owner (solo developer, solo travel content creator). It is the complete, self-contained specification of what Arc is, what to build, and in what order. Assume the reader has no conversation history — every doc must stand alone.

`README.md` stays the 2-minute human orientation. Do not duplicate spec content there; link into `docs/` instead.

Arc in one sentence: an iPhone-first capture-planning and field-execution app for a solo travel content creator — import a trip plan, execute it as a staged field guide one stage at a time, fall back to the Story Safety Net, review the completed shoot, and generate the editing script from execution data.

## 2. Current Implementation vs Target

Use this table to avoid confusing the current prototype with the target architecture. The roadmap in [docs/08-roadmap.md](08-roadmap.md) remains the source of truth for what to build next.

| Area | Current implementation | Target state | Roadmap owner |
|---|---|---|---|
| Root object | `Trip` owns artifacts, days, stops, stages, and capture items. | Same, with sync/platform work only after gates. | P2/P5 in [08-roadmap.md](08-roadmap.md) |
| Import | Paste/share/open/App Intent feed an `ArcPlanDocument`; `.arcguide` files skip parsing and commit into a fresh `Trip`. | T1/T2 quality continues to improve, but T0 remains the guaranteed floor. | P1/P2 in [08-roadmap.md](08-roadmap.md) |
| Stage storage | `Stage` is a persisted entity with `goal`, `kind`, and stable identity. | Same, plus optional location surfacing and Live Activity state after G1. | P2/P3 |
| Imported location | `Stop.latitude` / `Stop.longitude` are optional; unresolved stops keep verbatim `sourceGeoAnchor`. | Resolution UX improves, never fabricated coordinates. | P2 |
| Field UX | Trip timeline, map, stage mantra, capture/skip/note/photo, high contrast, structured Safety Net stage, and completion prompt. | Stricter glanceable no-scroll field surface, golden-hour nudge, optional while-in-use surfacing. | P3 after G1 |
| Review/export | Completion generates a script artifact; completed screen shares markdown and `.arcguide`. | Off-app web preview and email capture after G2. | P3/P4 |
| Tests | `ArcTests` covers document codec, parser, corpus fixtures, and schema-v2 mapper/export round-trip. | Corpus grows with every real trip. | P0 onward |

## 3. Precedence

When sources conflict, resolve in this order. State conflicts explicitly in your change description; never silently pick one.

1. **AGENTS.md** governs **how** agents work (conduct, tooling discipline, hard bans such as background execution/location without an explicit product requirement — see AGENTS.md:30 and [docs/adr/ADR-0007-while-in-use-location-surfacing.md](adr/ADR-0007-while-in-use-location-surfacing.md)). It always wins on conduct.
2. **docs/** governs **what** to build. Each topic has exactly one owner doc (see the map below); other docs link to it rather than restating it.
3. **[docs/08-roadmap.md](08-roadmap.md)** governs what to build **now**. If a spec exists in docs/ but the current phase does not call for it, do not build it.
4. **Phase non-goals beat everything.** If the current phase in docs/08 lists something as a non-goal, do not implement it even if another doc specifies it in detail.

The milestone gates table (G1–G4) lives only in [docs/02-business.md](02-business.md). Every other doc references it; none may restate it.

## 4. Doc Map

| File | The question it answers | Read it when |
|---|---|---|
| [01-product.md](01-product.md) | What is Arc and why does it exist? Positioning and binding product principles. | Before any feature work; when a design decision needs a product tiebreaker. |
| [02-business.md](02-business.md) | How does the business flywheel work? Milestone gates G1–G4 (single source of truth). | Before starting or exiting a phase; when anything mentions gates, email capture, or monetization. |
| [03-market-research.md](03-market-research.md) | What did the market look like at the July 2026 snapshot? | When questioning positioning. Dated evidence — do not cite as current. |
| [04-architecture.md](04-architecture.md) | How is the code organized today, what gets added per phase, and what debt is tracked? | Before touching code structure; when placing a new file or service. |
| [05-data-model.md](05-data-model.md) | What are the schema v2 entities and the ArcPlanDocument/ArcGuideDocument spec? | The most-consulted doc. Before any model, persistence, or interchange change. |
| [06-import-spec.md](06-import-spec.md) | What formats does import accept? Arc-Flavored Plan conventions, ChatGPT template, parsing tiers T0–T3. | Before touching the import pipeline or parser heuristics. |
| [07-field-ux.md](07-field-ux.md) | What are the binding field-UX principles? | Before touching any in-field screen or interaction. |
| [08-roadmap.md](08-roadmap.md) | What do I build now? Phases P0–P5, acceptance criteria, non-goals. | At the start of every work session. |
| [09-quality.md](09-quality.md) | How is Arc tested? Test targets and the parsing eval harness. | Before writing tests; before claiming import quality improved. |
| [adr/](adr/) | Why was each irreversible decision made? ADR-0001 through ADR-0007 + template. | When a spec seems arbitrary; before proposing to reverse a recorded decision. |

## 5. Agent Brief Header Spec

Every doc in `docs/` (ADRs excluded) starts with this blockquote, adapted per doc:

```markdown
> **Agent Brief** — Status: Current | Applies to: <phases or All> | Owner doc for: <topic>
> Read [docs/00-index.md](00-index.md) first. Behavioral rules: /AGENTS.md (wins on conduct). Current build phase: see [docs/08-roadmap.md](08-roadmap.md).
> Code pointers verified against <branch @ commit or branch name> (<YYYY-MM-DD>). Re-verify line numbers before editing.
```

Status values:

| Status | Meaning | Agent action |
|---|---|---|
| `Current` | Verified accurate as of the stamp on line 3. | Trust it; still re-verify line-number code pointers before editing code. |
| `Stale — needs re-verification` | Known or suspected drift from code/reality. | Re-verify claims against the codebase before relying on them; update the doc and restore `Current`. |
| `Superseded` | Replaced by a newer doc or ADR named in the header. | Do not implement from it; follow the replacement. |

When you verify or update a doc, update its verification stamp (branch @ commit + date) in the same change.

## 6. Doc-Update Discipline

- Any change that alters the **data model**, **import behavior**, or **field UX** must update the owning doc ([05](05-data-model.md), [06](06-import-spec.md), or [07](07-field-ux.md)) in the same change. This mirrors the change discipline in /AGENTS.md.
- ADRs are **immutable once Accepted**. Never edit an Accepted ADR — write a new ADR that supersedes it (using [adr/ADR-0000-template.md](adr/ADR-0000-template.md)) and mark the old one `Superseded` with a link.
- If a change makes any doc's claims wrong and you cannot fix that doc in the same change, downgrade its Status to `Stale — needs re-verification` — do not leave it marked `Current`.
- Never restate owned content (gates table, schema definitions, phase criteria) in a second doc. Link to the owner.

## 7. Glossary

Use these exact terms everywhere — code, docs, commit messages, UI copy discussions.

| Term | Definition |
|---|---|
| **Trip** | Schema v2 root entity: one real-world trip, owning artifacts and shoot days. |
| **TripArtifact** | Per-trip document; `kind` is `ideas`, `shootList`, or `script`. Script is bidirectional: Arc generates it from execution data. |
| **ShootDay** | One calendar day of shooting within a Trip; owns Stops. |
| **Stop** | A physical place visited on a ShootDay; carries `sourceGeoAnchor`; owns Stages. |
| **Stage** | An ordered execution unit within a Stop; `kind` is `standard`, `beforeLeaving`, or `safetyNet`. |
| **CaptureItem** | A single shot/sound/note to capture within a Stage; `origin` is `planned`, `safetyNet`, or `fieldAdded`. |
| **ArcPlanDocument / ArcGuideDocument** | One JSON interchange schema, `kind` `plan` or `guide`, integer `schemaVersion`, UTType `com.arc.guide`, extension `.arcguide`. Lives in `Arc/Core/Documents/` (never imports SwiftData). See [05-data-model.md](05-data-model.md). |
| **Arc-Flavored Plan (AFP)** | The markdown conventions the T0 parser guarantees to parse. See [06-import-spec.md](06-import-spec.md). |
| **geo anchor** | A verbatim Google Maps link / address / time-prefix line preserved from source text into `Stop.sourceGeoAnchor`. |
| **stage mantra** | The glanceable field summary of a Stage: `Stage.goal` + musts remaining. |
| **story is safe** | State where all must-priority and before-leaving items in scope are resolved (captured or skipped). |
| **Story Safety Net** | Fallback stage of minimum-viable coverage items ensuring a publishable story even when the plan collapses. |
| **before-you-leave** | A `beforeLeaving` Stage: the checkpoint verified before departing a Stop. |
| **field-verified** | A guide auto-drafted from an actually executed trip — Arc's long-term provenance claim in the guide economy. |
| **gates G1–G4** | Channel milestones gating phases (dogfood proven, channel live, audience signal, willingness-to-pay). Table lives only in [02-business.md](02-business.md). |
