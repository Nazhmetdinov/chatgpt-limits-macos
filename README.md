# ChatGPT Limits for macOS

A native menu bar monitor for ChatGPT Work / Codex subscription usage, reset times, and available extra resets. Supports **Plus and Pro** using the limits reported by your account.

[Русская документация](README.ru.md) · [Contributing](CONTRIBUTING.md) · [Release guide](docs/RELEASING.md)

An independent, unofficial project. Not affiliated with OpenAI. The app interface is currently in Russian.

## Install without Terminal

**[Download ChatGPT Limits 1.3.6 — DMG](https://github.com/Nazhmetdinov/chatgpt-limits-macos/releases/download/v1.3.6/ChatGPT-Limits-v1.3.6-macOS-universal.dmg)**: one file for Apple Silicon and Intel. [All release files](https://github.com/Nazhmetdinov/chatgpt-limits-macos/releases/latest). Requires macOS 13+ and an installed, signed-in ChatGPT or Codex client. Swift and developer tools are not needed.

1. Download and open the DMG.
2. Drag **ChatGPT Limits** onto **Applications**.
3. Launch it from Applications and allow notifications. **GPT** appears in the menu bar. Eject the ChatGPT Limits disk in Finder.

The DMG includes **Install.html** with instructions. Before updating, quit the monitor and replace it in the same folder as the previous version.

The current DMG is not Developer ID signed or notarized yet. If macOS blocks it and you trust the source, the available Open Anyway action in Privacy & Security may be needed after an attempted launch. See [Apple's instructions](https://support.apple.com/102445). Developer ID signing and notarization remain a maintainer step before a standard public release.

**Plus — two periods**

![Plus preview with synthetic usage](docs/images/plus.png)

**Pro — weekly period**

![Pro preview with synthetic usage](docs/images/pro.png)

Screenshots use **synthetic fixtures**, not a real account. Actual windows and balances come from the service.

## What it shows

| | Plus | Pro |
| --- | --- | --- |
| Periods | Five-hour window; weekly window when returned | Weekly window; currently no five-hour window |
| Menu example | `GPT 5ч 65%/2ч · 7д 32%/5д · ↻1` | `GPT 72% · 4д · ↻2` |
| Meaning | Period, remaining percentage, time to reset | Remaining percentage, time to reset |
| Extra resets | Available count, or `—` if unavailable | Available count, or `—` if unavailable |

`д`, `ч`, and `м` mean days, hours, and minutes; `↻` is the available reset count. Clicking opens all reported categories, exact local reset dates, and reset details when provided. Multiple windows appear separately in the menu bar. Stale data gets a `!`; expired windows remain unknown until the server confirms a new period.

The service reports **percentages, not a fixed number of remaining tokens**. This monitors Work / Codex usage, not ordinary ChatGPT conversations or API billing. Plan names, windows, percentages, and reset credits are read dynamically; there are no fixed token allowances or assumed reset grants. Entitlements may change. See the official [pricing and limits](https://learn.chatgpt.com/docs/pricing) and [App Server protocol](https://learn.chatgpt.com/docs/app-server).

## Subscription management

**Управление подпиской** opens ChatGPT subscription settings in a new tab in Chrome/Chromium, Edge, Brave, Vivaldi and Firefox when one of these is the default browser. Safari and other browsers follow their own external-link tab/window preferences. A browser window is created if none is open. No separate sign-in window, browser extension, or developer-mode setup is required by the monitor.

The **Следующая оплата** card displays a locally verified date when a snapshot for the current account and plan is present, or **Дата недоступна** otherwise. The snapshot records when the date was checked on the ChatGPT subscription page, marks it as needing verification after 24 hours, and never rolls it forward automatically. Currently this is populated only during assisted verification; ordinary installation does not automatically import a date. Automatic next-payment updates are not available in this version: the installed client's limits response does not include billing dates. The monitor does not infer them from usage resets. Manage payments through the service where the subscription was purchased (ChatGPT, App Store, Google Play, or another provider).

## Notifications

- **Below 10% remaining:** once per window per period. Exactly 10% does not trigger it. An already low balance triggers a warning on the first successful check.
- **Limit reset:** only after a fresh response confirms a new period. A countdown reaching zero alone does not trigger it.
- **Extra reset granted:** when the available count increases, or a new grant identifier is observed even if the balance is unchanged.

Each Plus window is tracked independently. Initial balances establish a baseline and are not reported as new grants. Missing fields and restarts do not repeat notifications. A reported plan change establishes a new baseline. Pending events expire after 24 hours; obsolete low-balance warnings are removed sooner.

Allow notifications when macOS prompts. The panel includes status, system settings, and a **Тест** button. System Focus, sound, and banner settings still apply. Checks run every five minutes, on wake, and on manual refresh; the app must be running. If a grant and spend happen between checks with no balance change and no grant details, that event cannot be detected.

## Build from source — for developers

Requirements: **macOS 13+**, **Swift 6 / Xcode Command Line Tools**, and an installed ChatGPT or Codex client signed in to a supported ChatGPT account. No API key is required. If Command Line Tools is missing, install it with `xcode-select --install`.

```sh
swift run --disable-sandbox LimitsChecks
bash scripts/build.sh
bash scripts/install.sh
```

The app installs to `~/Applications/ChatGPT Limits.app`, without a Dock icon. It registers launch at login on first start; toggle **Запускать при входе** in the panel to disable it. macOS may require approval in Login Items. Notifications need their separate system permission.

For updates, quit the monitor first. The install script verifies and backs up the previous app under `dist/backups`. To roll back, quit the monitor and copy that backup to `~/Applications/ChatGPT Limits.app`.

Builds use an **ad-hoc signature** and are not notarized. `bash scripts/build.sh --universal` builds both Apple Silicon and Intel slices. `bash scripts/package-release.sh` creates a DMG, ZIP, and checksums. CI checks both architectures; locally, arm64 has been run and x86_64 has been cross-compiled.

## How it works and privacy

The app starts the installed `codex app-server` over stdio, sends `initialize` and `account/rateLimits/read`, then stops that child process. It uses the client's existing login. It does not read or copy credential files, call a model, buy credits, or redeem resets. The installed client handles authentication and its own network traffic.

It prefers `rateLimitsByLimitId`, with a legacy `rateLimits` fallback. The reset balance comes from `availableCount`, not from the length of a possibly truncated details list. Unknown fields remain unknown.

The monitor has no telemetry. It stores a minimal notification baseline and pending events in macOS preferences: prior percentages, reset times, grant IDs, and counts. If the response includes an account ID, only its SHA-256 fingerprint is retained. Full responses and credentials are not saved in these preferences. An optional private `verified-billing.json` under this utility’s Application Support folder holds only an account fingerprint, plan, observed renewal day, source label and verification time. It contains no invoices or payment details. If account identity is absent, switches between accounts on the same plan cannot always be distinguished; clearing the closed app's preferences resets its baseline and notification history.

## Development and checks

```sh
# Offline behavior checks; no account needed
swift run --disable-sandbox LimitsChecks

# Current account, without the interface
"dist/ChatGPT Limits.app/Contents/MacOS/ChatGPTLimits" --check

# Documentation images from synthetic inputs only
bash scripts/render-previews.sh

# Audit tracked publication files and package the app
python3 scripts/audit-release.py
bash scripts/package-release.sh
```

`--check` prints a summary without credentials or account IDs. Do not publish diagnostics from a real account. See [RELEASING.md](docs/RELEASING.md) for source archives, signatures, and GitHub publication steps.

Licensed under [MIT](LICENSE).
