# Security

This is an independent local utility. The latest source version is supported; there is no security response SLA.

Never attach credentials, authentication files, full account responses, or private diagnostics to a public issue. Use GitHub's **Report a vulnerability** feature when enabled for the repository. If unavailable, open an issue requesting a private reporting channel without disclosing exploit details or sensitive data.

The app delegates authentication to the installed Codex client. It reads account limits only and never invokes reset redemption or model inference. Notification preferences contain usage history and grant identifiers; treat a macOS profile backup as personal data.

Release audits detect known secret formats and private home paths. They are a review aid, not proof that arbitrary input is safe to publish. Documentation images must come from synthetic fixtures. Public binaries are ad-hoc signed unless a release explicitly documents Developer ID signing and notarization.
