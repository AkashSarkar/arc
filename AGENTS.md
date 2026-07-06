# AGENTS.md

## Purpose

This file is the canonical instruction set for any AI agent working in this repository.

Arc is a privacy-conscious, performance-sensitive iOS app built with SwiftUI, SwiftData, and Apple system frameworks. Agents should make small, coherent changes that preserve readability, maintainability, and product safety.

## Product Context

- Platform: iOS 26, iPhone-first.
- Core UX: location selection, planning, field execution, and review for solo creators.
- Key constraints: fast startup, responsive UI, strong privacy defaults, low operational risk, and readable outdoor field-mode experiences.

## Project Documentation

- Before non-trivial work, read [docs/00-index.md](docs/00-index.md).
- Scope all work against the current phase in [docs/08-roadmap.md](docs/08-roadmap.md) and respect phase non-goals.
- Update the owning doc in the same change as any behavior or model change.
- ADRs in [docs/adr/](docs/adr/) are binding.
- Precedence: AGENTS.md governs conduct, docs/ governs what to build, docs/08-roadmap.md governs what to build now.

## Non-Negotiable Rules

- Never hardcode API keys, secrets, tokens, or personal data in source code, previews, tests, logs, or documentation.
- Use Keychain for secrets and generated Info.plist build settings for runtime configuration that is not secret.
- Prefer Apple frameworks first when they satisfy the requirement well.
- Do not add third-party dependencies unless the existing platform APIs are clearly insufficient and the tradeoff is justified.
- Do not weaken privacy, transport security, or permission boundaries to make a feature easier to implement.
- Do not introduce background execution, background location, or persistent tracking without an explicit product requirement. Scoped exception recorded in docs/adr/ADR-0007-while-in-use-location-surfacing.md.
- Fix the root cause when practical. Avoid superficial patches that leave the design worse.

## Repository Architecture

Use the current project structure consistently:

- `Arc/App`: app entry points and dependency wiring only.
- `Arc/Core`: cross-cutting foundations such as configuration, networking, security, and rate limiting.
- `Arc/Services`: adapters around external APIs or Apple system services.
- `Arc/Features`: feature-local UI, presentation logic, and domain types.
- `Arc/Assets.xcassets`: visual assets only.

### Architectural Guidelines

- Keep `AppContainer` responsible for composing live dependencies.
- Inject dependencies through initializers or dedicated factories. Do not add global mutable singletons.
- Keep SwiftUI views focused on rendering and user interaction.
- Move asynchronous work, side effects, validation, and state coordination into feature-local view models or services.
- Prefer `@MainActor @Observable` for feature presentation state when UI state coordination becomes non-trivial.
- Keep domain and service boundaries explicit with small protocols when the dependency crosses feature or infrastructure boundaries.
- Reuse existing models when possible. Avoid data-model churn unless it is necessary for the feature.

## Coding Principles

- Favor clarity over cleverness.
- Prefer small, composable types and focused functions.
- Use descriptive names. Avoid abbreviations unless they are standard Apple or domain terms.
- Prefer value types unless identity, persistence, or shared mutable state is required.
- Keep access control as tight as practical.
- Handle errors explicitly and surface human-readable failures with `LocalizedError` where appropriate.
- Avoid force unwraps. Use guards, typed errors, and safe fallbacks.
- Keep comments sparse and useful. Explain why, not what the code already says.
- Match the existing style of the surrounding code instead of introducing a parallel style.

## SwiftUI Best Practices

- Keep `body` declarations declarative and easy to scan.
- Do not bury business logic or asynchronous orchestration inside views.
- Break large views into smaller subviews when a screen starts carrying multiple responsibilities.
- Keep view state minimal. Do not store the same derived state in multiple places unless there is a strong reason.
- Use `Task` and structured concurrency carefully. Cancel or replace stale asynchronous work where appropriate.
- Keep UI-affecting state on the main actor.
- Prefer explicit loading, empty, error, and permission-denied states over hidden failure paths.
- Maintain accessibility: readable text, clear labels, sensible hit targets, and support for Dynamic Type where practical.

## UI and UX Expectations

- Build the user experience as part of the feature work. Do not defer visual hierarchy, readability, or interaction clarity to a later pass if the feature is user-facing.
- Follow Apple design language first. Prefer standard SwiftUI navigation, list, form, sheet, toolbar, and control behaviors before custom styling.
- Use Liquid Glass where the system already provides it automatically through standard components, and apply custom glass effects sparingly to high-value elements only.
- Favor calm, eye-soothing color choices with strong legibility over loud accenting or decorative gradients that compete with content.
- Keep the interface easy to understand at a glance. Important actions should be obvious, grouped logically, and supported by concise supporting text.
- When designing custom surfaces, prioritize contrast, spacing, and hierarchy so the experience remains clear in both light and dark appearances.
- Avoid overcrowding controls or layering too many translucent elements together. Readability and task focus are more important than showing more glass.
- For field-oriented screens, preserve usability outdoors by preferring high-contrast, sturdy controls over delicate translucent treatments when the context demands it.

## SwiftData Guidelines

- Keep `@Model` types stable and minimal.
- Avoid unnecessary schema changes. Only evolve the model when the product truly needs new persisted data.
- When editing an existing entity, mutate the existing model instance instead of inserting duplicates.
- Use `@Query` for straightforward fetches, but keep filtering, sorting policy, and transformation logic out of heavy view code when it grows complex.
- Be conscious of fetch volume and main-thread work. Large or repeated transformations should not happen in hot UI paths.

## Networking and External Services

- Use typed service abstractions in `Core` or `Services` instead of calling network or platform APIs directly from views.
- Use the existing `HTTPClient` abstraction for HTTP-based integrations unless there is a strong reason not to.
- Validate HTTP responses and map failures into explicit domain errors.
- Set sensible timeouts and keep requests cancellable.
- Retry only transient, safe-to-retry failures, and keep retry policies bounded.
- Do not log secrets, full request payloads with user content, or raw server responses unless required for debugging and clearly safe.
- Prefer ephemeral or privacy-preserving network configuration unless persistence is justified.

## Security and Privacy Rules

- Secrets belong in Keychain, not in source files.
- User-facing privacy permissions must be minimal, accurate, and tied to a real feature.
- Because this project uses a generated Info.plist, add new privacy strings through `Arc.xcodeproj/project.pbxproj` build settings instead of creating ad hoc configuration files.
- Use least privilege for permissions and capabilities.
- Validate and sanitize external input before using or persisting it.
- Fail closed when required configuration is missing.
- Avoid storing sensitive data unless it is required for the product.
- Be conservative with analytics, logging, and cached data.

## Performance Guidelines

- Keep the main thread free for rendering and user interaction.
- Avoid heavy parsing, image work, geocoding churn, or repeated network orchestration in view bodies.
- Debounce or coalesce repeated user-driven work such as search.
- Reuse work where practical and cancel stale requests aggressively.
- Prefer lazy and incremental loading patterns for lists, media, and search results.
- Measure before performing broad optimization refactors.
- Keep app launch lightweight. Avoid doing non-essential work in `App` initialization paths.
- Protect battery and data usage, especially for AI requests, location work, and media-heavy features.

## iOS and Apple Framework Guidance

- Prefer MapKit, CoreLocation, Vision, Foundation Models, and other first-party frameworks when they meet product needs.
- Treat permission handling as part of the feature design, not an afterthought.
- For location features, support denied or restricted permission states gracefully.
- Keep field workflows usable outdoors: high contrast, large tap targets, and minimal visual fragility.
- Use background capabilities only when required and intentionally reviewed.

## Change Discipline

- Make the smallest coherent change that fully solves the problem.
- Do not refactor unrelated files during a feature change unless it removes a direct blocker.
- Remove obsolete files, screens, helpers, and dead code as part of the change that makes them unreachable. Do not keep legacy code around "just in case"; if something must remain for a deliberate future use, document that reason where it lives.
- Preserve public APIs and file structure when possible.
- If a new capability requires project configuration, update the configuration in the same change.
- If a new pattern is introduced, apply it consistently within the local feature scope.
- New files should land in the correct architectural folder instead of convenience dumping into the nearest directory.

## Verification Expectations

- After code changes, check for compile errors in the touched files or affected area.
- Verify core user flows, failure states, and regressions introduced by the change.
- For permission-based features, validate both success and denial paths.
- For persisted data flows, verify create, update, and read behavior.
- If tests exist for the affected layer, update or add them. If no tests exist, keep logic factored so it can be tested later.

## Agent Workflow

- Read the relevant files before editing.
- Understand the existing pattern in the local feature before introducing new abstractions.
- Prefer one canonical implementation over duplicated helper logic.
- Avoid speculative architecture. Add indirection only when the codebase will clearly benefit from it.
- Preserve user-authored changes unless explicitly asked to replace them.
- Document important architectural or security decisions in code or project docs when they are not obvious.

## Current Project Conventions

- `AppContainer` is the dependency-composition entry point.
- `ArcApp` owns the root scene and SwiftData model container setup.
- Security-sensitive values are read from Keychain through `KeychainStore`.
- The network layer currently favors explicit protocols and typed decoding.
- Feature complexity should generally be expressed through feature-local presentation models rather than by bloating SwiftUI views.

When in doubt, choose the option that improves correctness, readability, and privacy with the least architectural weight.
