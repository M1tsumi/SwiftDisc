# Contributing to SwiftDisc

SwiftDisc is built around Swift 6 concurrency, typed throws, and actor-based APIs. Keep changes focused, source-compatible when possible, and covered by tests.

## Workflow

1. Open an issue or discussion for anything larger than a bug fix.
2. Keep changes small and scoped to one release theme.
3. Update tests and docs together with code when behavior changes.

## Build and Test

- Build: `swift build`
- Test: `swift test`
- Focused tests: `swift test --filter <TestName>`

## Style

- Prefer additive APIs over breaking ones.
- Keep public names consistent with existing SwiftDisc conventions.
- Use `@Sendable` closures for callbacks that can cross tasks or actors.

## Comment Style

- Write comments for intent and edge cases, not obvious syntax.
- Keep comments concise and specific to the code directly below them.
- Prefer practical wording over marketing language.
- Avoid filler phrases and AI-like boilerplate.
- When behavior is surprising (rate limits, retries, protocol quirks), explain the "why" in one or two lines.

## PR Checklist

- Tests added or updated for the behavior change.
- Documentation updated when public APIs or developer workflows change.
- No new compiler warnings.
- Release notes or changelog updated when the change is user-facing.