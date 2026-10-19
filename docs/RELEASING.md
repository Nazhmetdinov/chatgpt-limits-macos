# Release preparation and GitHub publication

Release **1.3.6** includes a panel that fits its content and a flat green conversation mark with a quota arc and an AI spark. It includes a next-payment card for optional, locally verified renewal snapshots and a default-browser subscription-management link. Personal snapshots are never bundled, committed or published; other users see unavailable until a date has been verified for their account. Chromium browsers and Firefox use a new-tab command; Safari and other browsers retain their own link-opening preferences. Automatic billing-date retrieval is still unavailable. Creating a local commit or archive does not publish a repository or release.

Public repository: `Nazhmetdinov/chatgpt-limits-macos`.

Description: **Native macOS menu bar monitor for ChatGPT Work / Codex limits, resets, and notifications. Supports Plus and Pro.**

Topics: `macos`, `swift`, `menubar`, `chatgpt`, `codex`, `usage-monitor`.

## Validate and package

Run inside the dedicated project repository, never from its parent workspace. Include only this project's sources, documentation, and synthetic fixtures.

```sh
swift run --disable-sandbox LimitsChecks
bash scripts/build.sh --universal
bash scripts/render-previews.sh
git add .gitignore .gitattributes Package.swift VERSION LICENSE README.md README.ru.md CHANGELOG.md CONTRIBUTING.md SECURITY.md Sources Tests scripts .github docs
python3 scripts/audit-release.py --staged
bash scripts/package-release.sh
```

Review the staged diff and both previews. The audit checks exact index contents with `--staged`; packaging checks the binary separately. Apps, backups, diagnostics, and archives are ignored. The audit refuses a Git root outside this directory.

After committing and tagging the reviewed source, create a source archive:

```sh
VERSION="$(cat VERSION)"
git archive --format=tar.gz --prefix="chatgpt-limits-macos-$VERSION/" \
  --output="dist/release/chatgpt-limits-macos-$VERSION-source.tar.gz" "v$VERSION"
(cd dist/release && shasum -a 256 "chatgpt-limits-macos-$VERSION-source.tar.gz" \
  > "chatgpt-limits-macos-$VERSION-source.tar.gz.sha256")
```

Packaging creates a universal DMG for regular users and a ZIP alternative. The DMG contains the app, an Applications shortcut, and bilingual Install.html. Both architecture slices are built locally; arm64 has been run, and Plus uses synthetic fixtures. CI also runs checks on x86_64, but its status is unknown until run on GitHub. Do not describe Plus as verified against a live Plus account or Intel as locally run.

## Publish a release

Push the reviewed source to `main`, then open **Actions → macOS checks and builds → Run workflow**. Select `main`, enable **Publish the version in VERSION after both architecture checks pass**, and run it. Ordinary pushes and pull requests only validate and package; they never publish.

The release job runs only when both macOS architecture jobs succeed. It downloads the universal build from the same workflow run, creates a source archive from the exact tested commit, verifies SHA-256 checksums, and publishes the version from `VERSION` with its release notes. Only this final job has a temporary repository-scoped token with permission to write releases. No personal token or saved credentials are required.

The workflow creates a new tag and release; it fails rather than replacing an existing release. Inspect any existing version before changing it. Make the universal DMG the primary user download. Review public visibility, download links, the six uploaded assets, and Actions results after publication.

## Signing and future versions

Current archives are ad-hoc signed and **not notarized**. For notarized downloads, sign with the maintainer's Developer ID, submit to Apple's notary service, staple the accepted ticket, verify Gatekeeper acceptance, then regenerate the archive and checksum. Signing credentials stay outside Git and require a separate maintainer setup.

Before a notarized release, update the unsigned-build notices in both READMEs and `docs/Install.html` to match the verified signing state. DMG packaging does not replace Developer ID signing or notarization. Do not remove these notices merely because a DMG has been created.

For a new version, update `VERSION`, the App Server `clientInfo.version` in `LimitsReader.swift`, the changelog, and release notes. Keep bundle identity stable to preserve preferences and login items. Re-run checks and audits before tagging. Regenerate synthetic screenshots with `scripts/render-previews.sh`.
