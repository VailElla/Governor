# Governor v0.2.0 — UNNOTARIZED manual-install pre-release

> These are **UNNOTARIZED manual-install assets**. They are ad hoc signed and
> require an explicit, per-Mac Gatekeeper exception after checksum verification.
> They cannot register the privileged Helper and are not a functioning
> no-repeat-password release.

> **Build 4:** The app disables automation in these assets and explains that
> Governor will not appear in Login Items. It no longer sends users to approve
> a Helper that macOS cannot register.

## Install the UNNOTARIZED app

1. Download the DMG and its matching `.sha256` file, then verify it before
   opening anything:

   ```bash
   shasum -a 256 -c Governor-v0.2.0-UNNOTARIZED-macOS-arm64.dmg.sha256
   ```

2. Open the DMG and drag `Governor.app` to `Applications`.
3. Try to open the app once. Then open **System Settings → Privacy & Security**,
   scroll to **Security**, choose **Open Anyway**, and confirm the next dialog.
   macOS may ask for the local account password. This creates an exception for
   this app on this Mac; it is not a Developer ID signature or notarization.

Do not disable Gatekeeper globally or strip a downloaded app's quarantine
attribute with Terminal commands. Only use the per-app exception after verifying
the release URL and SHA-256 checksum.

## SMAppService power helper

- Replaces the deprecated in-process privileged executor with a bundled `SMAppService` LaunchDaemon.
- The root Helper exposes one code-signed XPC method only. It accepts three enumerated values and constructs a fixed `/usr/bin/pmset` allow-list itself; it accepts no shell, executable path, environment, arbitrary command, or arbitrary arguments.
- In a Developer ID-signed and Apple-notarized build installed in `/Applications`, the user approves the daemon once in System Settings > General > Login Items. Later lock/unlock, app relaunch, and automation enable actions do not request an administrator password again.

## Asset status

`Governor-v0.2.0-UNNOTARIZED-*` assets are free manual-install assets. They are ad hoc signed, not notarized, and not Developer ID-trusted. Apple requires a notarized app for an `SMAppService` LaunchDaemon, so these assets cannot register the privileged Helper and must not be represented as a functioning no-repeat-password release. SHA-256 files detect download corruption or change; they do not prove publisher identity.

## Test scope

- Passed unit, state-machine, allow-list, build, package, ZIP extraction, DMG mount, signature, and SHA-256 verification.
- No test put the Mac to sleep, restarted, shut down, logged out, or disconnected networking.
- Lock/unlock, app-relaunch, reboot persistence, and daemon approval behavior were simulated/static-validated only; no claim of a physical power-lifecycle test is made.
