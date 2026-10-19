# Changelog

## 1.3.6 — 2026-10-19

- Replace the plain hexagon with an original flat green conversation mark, combining a quota arc with an AI spark.
- Refresh synthetic Plus and Pro previews.

## 1.3.5 — 2026-10-19

- Simplify the header mark to one flat green hexagon outline, without interwoven lines, shadows or gradients.
- Keep the compact panel layout and existing functionality unchanged.

## 1.3.4 — 2026-10-19

- Size the menu panel to its content, removing unused space beneath the subscription card for both Plus and Pro. Keep scrolling when the full content exceeds the screen height.
- Replace the green pie-chart header symbol with an original monochrome vector loop mark.
- Refresh synthetic documentation previews; preserve usage, renewal snapshots and notifications.

## 1.3.3 — 2026-10-19

- Restore the next-payment card with account-bound, locally verified renewal snapshots and a visible verification date. Show unavailable when no matching snapshot exists; flag observations after 24 hours and never estimate the next renewal. Automatic updates remain unavailable.
- Open subscription management through the default browser’s new-tab command in Chromium browsers and Firefox. Other browsers retain their own link-opening preferences.
- Keep browser authentication, extensions and automation permissions out of the setup flow.

## 1.3.2 — 2026-10-19

- Withdraw the experimental renewal integration and its browser extension/native helper.
- Keep one standalone app with a subscription-management link in the default browser.
- Clearly document that automatic billing dates are unavailable from the limits source.
- Preserve Plus/Pro limits, reset countdowns and all three notification types.
- Build and install fresh bundles so obsolete components are removed on update.

## 1.3.1 — 2026-10-19 (withdrawn local beta)

- Replace embedded login with the system default browser.
- Bundle a Chromium extension and bounded native-messaging relay for subscription metadata; no credential import.
- Preserve polling across worker restarts and stop data transfer on disconnect.
- Document explicit extension installation, supported browsers, and pending live validation.

## 1.3.0 — 2026-10-19 (withdrawn local beta)

- Add optional automatic subscription renewal lookup through a separate ChatGPT web sign-in (beta).
- Determine Web, App Store, Google Play, partner and trial origins from server data.
- Handle cancellation, missing/past dates and payment-status errors without guessing a charge date.
- Isolate the web session from existing client/browser credentials and bind results to the limits account.
- Add disconnect with local WebKit session removal, 30 core checks, and offline web-adapter contract checks.
- Document the undocumented endpoint and pending live validation across purchase channels.

## 1.2.0 — 2026-10-19

- Add a universal DMG for drag-and-drop installation on Apple Silicon and Intel, with an Applications shortcut and bilingual installation instructions.
- Display Plus five-hour and weekly limits separately, with both countdowns in the menu bar.
- Preserve Pro's compact single-window display; show only windows reported by the service.
- Refresh when any displayed window expires, including a less depleted Plus window.
- Track notifications independently per window; rebaseline after a reported plan change.
- Retain the last known deadline when a response temporarily omits it.
- Add synthetic Plus/Pro fixtures, offline preview rendering, and 24 core behavior checks.
- Prepare MIT-licensed sources, English/Russian documentation, architecture-specific CI builds, and audited release packaging.

## 1.1.0 — 2026-10-19

- Add native notifications below 10% remaining, after confirmed resets, and for newly granted reset credits.
- Persist minimal notification state and avoid duplicate events across restarts.
- Add notification status, settings, and a test action.

## 1.0.0 — 2026-10-19

- Add the native menu bar monitor, reset countdowns, available reset credits, and launch at login.
- Read limits through the installed Codex App Server without running a model.
