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

## PR Checklist

- Tests added or updated for the behavior change.
- Documentation updated when public APIs or developer workflows change.
- No new compiler warnings.
- Release notes or changelog updated when the change is user-facing.