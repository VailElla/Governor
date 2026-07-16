# Governor v0.2.3 build 7 — UNNOTARIZED manual-install patch release

> These are **UNNOTARIZED manual-install assets**. They are ad hoc signed and
> have not been notarized by Apple. They are not Developer ID-trusted releases.

## What's fixed

- Fixed the `i` help icons in Automation Settings so hovering shows the
  explanation popover instead of doing nothing.
- The help affordance now has a reliable hit area, supports click as a fallback,
  and retains the native macOS help and accessibility label.

## Install the UNNOTARIZED app

1. Download the DMG and its matching `.sha256` file, then verify it:

   ```bash
   shasum -a 256 -c Governor-v0.2.3-UNNOTARIZED-macOS-arm64.dmg.sha256
   ```

2. Open the DMG and drag `Governor.app` to `Applications`.
3. Try to open the app once. Then open **System Settings → Privacy & Security**,
   choose **Open Anyway**, and confirm the next dialog.
4. In Governor, enable Automation and approve the administrator prompt.

This build is ad hoc signed, unnotarized, and uses session-only administrator
authorization. The authorization ends when Governor quits; Governor will not
appear in Login Items. Do not disable Gatekeeper globally or remove quarantine
attributes with Terminal.

Upgrading from MacPower? Quit it and move `MacPower.app` to Trash before
installing `Governor.app`. Do not keep both apps installed or running.

## Test scope

- Unit and policy tests passed.
- Release bundle, signature, ZIP, DMG mount, extraction, and SHA-256 checks
  passed locally.
- No test requested real administrator authorization or a physical power
  lifecycle.
