# Contributing

Arrowslit is a small, owner-maintained GPL-3.0-or-later project. It includes a substantial
port of Notch Shell, so the project is local-only and copyleft rather than original-only.

## Before you contribute

- **Respect the license and attribution.** Code ported from Notch Shell is credited in
  `NOTICE` and covered by the GNU GPL. Do not copy code, comments, assets or UI text from other
  projects unless their license is compatible and you add the required attribution.
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
- Keep the visual language warm, quiet and architectural. Ported Notch Shell surfaces stay
  attributed; new surfaces should not copy another app's chrome.
