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

## Publish the prepared repository

These are explicit publication steps, not part of build or install scripts. They require an account with repository-creation rights and an authenticated GitHub CLI (`gh`). No credentials belong in Git.

1. Create an empty **public** repository named `chatgpt-limits-macos` under the intended account. Do not initialize it with an extra README or license. With the authenticated CLI:

   ```sh
   gh repo create Nazhmetdinov/chatgpt-limits-macos --public \
     --description "Native macOS menu bar monitor for ChatGPT Work / Codex limits, resets, and notifications. Supports Plus and Pro."
   git remote add origin https://github.com/Nazhmetdinov/chatgpt-limits-macos.git
   git push -u origin HEAD:main
   git push origin v1.3.6
   gh repo edit Nazhmetdinov/chatgpt-limits-macos --default-branch main --enable-private-vulnerability-reporting
   ```

   If the repository or remote exists, inspect it first. Do not overwrite or force-push existing history.

2. Wait for the macOS CI checks and inspect both architecture artifacts. Review repository visibility, license, documentation images, and Actions results.
3. Create a draft release and attach audited archives with checksums:

   ```sh
   gh release create v1.3.6 --repo Nazhmetdinov/chatgpt-limits-macos \
     --draft --verify-tag --title "ChatGPT Limits 1.3.6" \
     --notes-file docs/RELEASE_NOTES_1.3.6.md \
     dist/release/ChatGPT-Limits-v1.3.6-macOS-universal.dmg \
     dist/release/ChatGPT-Limits-v1.3.6-macOS-universal.dmg.sha256 \
     dist/release/ChatGPT-Limits-v1.3.6-macOS-universal.zip \
     dist/release/ChatGPT-Limits-v1.3.6-macOS-universal.zip.sha256 \
     dist/release/chatgpt-limits-macos-1.3.6-source.tar.gz \
     dist/release/chatgpt-limits-macos-1.3.6-source.tar.gz.sha256
   ```

   Wait for both architecture jobs before publishing the universal download. Make the DMG the primary user-facing asset. Review the draft and publish it in GitHub Releases only with its stated validation and signing limits. Do not publish the withdrawn 1.3.0/1.3.1 beta artifacts.

## Signing and future versions

Current archives are ad-hoc signed and **not notarized**. For notarized downloads, sign with the maintainer's Developer ID, submit to Apple's notary service, staple the accepted ticket, verify Gatekeeper acceptance, then regenerate the archive and checksum. Signing credentials stay outside Git and require a separate maintainer setup.

Before a notarized release, update the unsigned-build notices in both READMEs and `docs/Install.html` to match the verified signing state. DMG packaging does not replace Developer ID signing or notarization. Do not remove these notices merely because a DMG has been created.

For a new version, update `VERSION`, the App Server `clientInfo.version` in `LimitsReader.swift`, the changelog, and release notes. Keep bundle identity stable to preserve preferences and login items. Re-run checks and audits before tagging. Regenerate synthetic screenshots with `scripts/render-previews.sh`.
