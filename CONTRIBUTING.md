# Contributing

Use macOS 13+ and Swift 6. No third-party Swift dependencies are required. The UI is currently Russian; English localization is welcome.

1. Create a focused branch and keep changes scoped to the reported problem.
2. Add a synthetic fixture or behavior check for quota or notification logic changes. Never commit a real account response.
3. Run `swift run --disable-sandbox LimitsChecks` and `bash scripts/build.sh`.
4. For UI changes, run `bash scripts/render-previews.sh` and inspect both Plus and Pro images.
5. Stage intended files and run `python3 scripts/audit-release.py --staged`.

The checks are a standalone Swift executable so Command Line Tools installations without XCTest can run them. A login is needed only for the optional `--check` smoke test. Never run authenticated checks in CI or add credentials to workflows.

Report the macOS version, architecture, app version, and steps to reproduce. Remove personal paths, account identifiers, usage details, and secrets from reports. Use fabricated percentages and times in examples. See [SECURITY.md](SECURITY.md) for sensitive reports.
