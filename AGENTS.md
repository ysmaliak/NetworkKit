# Repository Guidelines

## Project Structure & Module Organization
- `Package.swift` — SwiftPM manifest (Swift 6, StrictConcurrency).
- `Sources/NetworkKit` — library code:
  - Core: `NetworkKit.swift`, `NetworkManager.swift`, `Configuration.swift`, `APIClient.swift`, `HTTPMethod.swift`.
  - Requests: `Request/`, `MultipartData.swift`.
  - Retry: `Retry/` (default, none, protocol).
  - Errors: `Errors/`.
  - Extensions: `Extensions/`.
  - Responses: `Responses/`.
  - Assets: `Resources/Localizable.xcstrings`.
- Tests: none yet. Place new tests in `Tests/NetworkKitTests`.

## Build, Test, and Development Commands
- Build: `swift build` — compile the package.
- Resolve deps: `swift package resolve` — fetch/update dependencies (none currently).
- Tests: `swift test` — run XCTest suite (create `Tests/` first).
- Coverage: `swift test --enable-code-coverage` — generate coverage data.
- Format (SwiftFormat): `swiftformat .` — apply repo formatting. Lint only: `swiftformat --lint .`.

## Coding Style & Naming Conventions
- Swift 6, 4‑space indentation, K&R braces; enforced by `.swiftformat`.
- Types: `UpperCamelCase`; methods/vars: `lowerCamelCase`; constants: same as vars.
- File names match primary type (e.g., `DefaultRetryPolicy.swift`). Use `Type+Feature.swift` for extensions.
- Concurrency: prefer `async/await`; avoid escaping closures when possible.
- Public API must be documented with concise doc comments.

## Testing Guidelines
- Framework: XCTest; place tests under `Tests/NetworkKitTests/*Tests.swift`.
- Name tests descriptively: `testFeature_whenCondition_thenBehavior`.
- Isolate networking with `URLProtocol` stubs; do not hit real endpoints.
- Aim for coverage on error paths (retry, auth, decoding).

## Commit & Pull Request Guidelines
- Commits: imperative, concise subject (≤72 chars). Example: `Add Strict Concurrency settings`.
- Include a brief body for context when changing behavior or APIs.
- PRs must include: clear description, rationale, before/after behavior, linked issues, and any screenshots or code samples.
- Update README and localized strings when user‑visible behavior changes.

## Security & Configuration Tips
- Never commit secrets or tokens. Avoid logging sensitive headers.
- Use `.none` auth for public endpoints in examples; show patterns, not real keys.
- Keep retries conservative; avoid unbounded loops.

## Agent‑Specific Instructions
- Follow this guide and `.swiftformat` rules for any edits.
- Keep changes focused; avoid unrelated refactors.
- Maintain API stability; deprecate before breaking when possible.
