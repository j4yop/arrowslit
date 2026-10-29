# Contributing

Arrowslit is currently a small, owner-maintained project. The goal is to keep the codebase
original, local-only and easy to license.

## Before you contribute

- **Do not copy code, comments, assets or UI text from another notch app.** Feature ideas are
  fine; expression is not.
- **Open an issue first** for anything larger than a small fix.
- **Contributions require a signed CLA with a copyright assignment** if they are accepted. A
  Developer Certificate of Origin (`Signed-off-by`) is not enough to keep the project
  dual-licensable. If you are not comfortable with that, please open an issue instead of a PR.
- By contributing, you confirm you have the right to submit the work and that it does not
  contain third-party code or assets under an incompatible license.

## Development

```bash
swift test
CONFIG=debug ./Scripts/build-app.sh
open "build/Arrowslit.app"
```

- Swift 6, macOS 14+
- Keep pure logic in `Sources/ArrowslitKit/Core`
- System integrations in `Services`
- SwiftUI in `UI`
- Add tests for pure logic; manual QA for system integration
- No network calls, analytics or accounts
- No polling when a feature is not visible
- Respect Reduce Motion and keyboard access

## Style

- Small, deep modules with clear names.
- Prefer value types and injected clocks for time-based logic.
- Comments explain *why*, not *what*.
- No force unwraps in new code unless the invariant is local and obvious.
- Keep the visual language warm, quiet and architectural; no copied notch-app chrome.
