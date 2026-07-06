# ADR-0000: ADR Template and Process

Status: Accepted
Date: 2026-07-06

## Purpose

This file is both the process rule-set for Architecture Decision Records in Arc and the copyable template. To record a new decision, copy the template block at the bottom to `docs/adr/ADR-XXXX-short-slug.md` (next free number, lowercase-hyphen slug) and fill in every section. Link the new ADR from [../00-index.md](../00-index.md).

## Field explanations

| Field | Rule |
|---|---|
| Title | `# ADR-XXXX: <decision as a short noun phrase>`. Name the decision, not the problem. |
| Status | One of `Proposed`, `Accepted`, `Superseded by ADR-XXXX`. Nothing else. |
| Date | ISO date (`YYYY-MM-DD`) the status last changed. |
| Context | 2-4 sentences. The forces and facts that made a decision necessary. Cite code pointers (`file.swift:line`) and sibling docs where relevant. No solutions here. |
| Decision | Imperative, concrete, testable. "Do X. Do not do Y." An agent must be able to check compliance against this section alone. |
| Consequences | Three parts: positive outcomes, negative outcomes / costs accepted, and follow-ups (work the decision creates, with the owning doc or phase). Honest negatives are mandatory. |
| Links | Relative markdown links to related docs (`../NN-*.md`) and ADRs (`ADR-XXXX-*.md`). |

## Immutability rule

**Never edit an Accepted ADR's Context, Decision, or Consequences.** Accepted ADRs are historical record; agents rely on them being stable.

- To change a decision: write a NEW ADR that states the new decision and names the old one. Then change the old ADR's Status line — and only its Status line — to `Superseded by ADR-XXXX`.
- Permitted edits to an Accepted ADR: the Status line, fixing broken links, and typo fixes that do not change meaning.
- ADRs in `Proposed` status may be edited freely until accepted.
- An ADR with a built-in expiry condition (e.g. [ADR-0003](ADR-0003-store-reset-pre-ship.md)) still requires an explicit superseding ADR (or Status flip referencing the trigger event) when the condition fires; expiry is not automatic.

## Precedence reminder

ADRs record durable decisions. `/AGENTS.md` governs agent conduct and wins on conduct. [../08-roadmap.md](../08-roadmap.md) governs what to build now; phase non-goals beat everything, including ADR follow-ups.

---

## Template (copy below this line)

# ADR-XXXX: <Decision title>

Status: Proposed | Accepted | Superseded by ADR-XXXX
Date: YYYY-MM-DD

## Context

<2-4 sentences: the forces, constraints, and verified facts that require a decision. Cite code pointers and docs.>

## Decision

<Imperative and concrete. What to do, what not to do, and the boundaries of scope.>

## Consequences

**Positive:**
- <benefit>

**Negative:**
- <cost accepted>

**Follow-ups:**
- <resulting work, with owning doc or phase>

## Links

- <related docs: `../NN-*.md`>
- <related ADRs: `ADR-XXXX-*.md`>
