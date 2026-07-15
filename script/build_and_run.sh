#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MacPower"
BUNDLE_ID="com.ella.MacPower"
MIN_SYSTEM_VERSION="13.0"
MODE="run"
DISTRIBUTION=0
MODE_SET=0

usage() {
  echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--bundle-only] [--distribution]" >&2
}

for argument in "$@"; do
  case "$argument" in
    --distribution)
      DISTRIBUTION=1
      ;;
    run|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify|--bundle-only|bundle-only)
      if [[ "$MODE_SET" -eq 1 ]]; then
        usage
        exit 2
      fi
      MODE="$argument"
      MODE_SET=1
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [[ "$DISTRIBUTION" -eq 1 && "$MODE" != "--bundle-only" && "$MODE" != "bundle-only" ]]; then
  echo "--distribution is only valid with --bundle-only" >&2
  exit 2
fi

CONFIGURATION="$(printenv MACPOWER_BUILD_CONFIGURATION || true)"
if [[ -z "$CONFIGURATION" ]]; then
  CONFIGURATION="debug"
fi
if [[ "$CONFIGURATION" != "debug" && "$CONFIGURATION" != "release" ]]; then
  echo "MACPOWER_BUILD_CONFIGURATION must be debug or release" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "$BASH_SOURCE")/.." && pwd)"
VERSION_FILE="$ROOT_DIR/VERSION"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_SOURCE="$ROOT_DIR/Resources/MacPower.icns"
APP_ICON="$APP_RESOURCES/MacPower.icns"
SIGNING_IDENTITY="-"
EXPECTED_TEAM_ID=""

if [[ "$DISTRIBUTION" -eq 1 ]]; then
  SIGNING_IDENTITY="$(printenv MACPOWER_SIGNING_IDENTITY || true)"
  EXPECTED_TEAM_ID="$(printenv MACPOWER_EXPECTED_TEAM_ID || true)"

  if [[ -z "$SIGNING_IDENTITY" ]]; then
    echo "Distribution builds require MACPOWER_SIGNING_IDENTITY." >&2
    exit 1
  fi
  if [[ -z "$EXPECTED_TEAM_ID" ]]; then
    echo "Distribution builds require MACPOWER_EXPECTED_TEAM_ID." >&2
    exit 1
  fi
  if [[ ! "$EXPECTED_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
    echo "MACPOWER_EXPECTED_TEAM_ID must be a 10-character Apple Team ID." >&2
    exit 1
  fi
fi

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "Missing version file: $VERSION_FILE" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$VERSION_FILE"

if [[ -z "$MACPOWER_VERSION" || -z "$MACPOWER_BUILD_NUMBER" || -z "$MACPOWER_RELEASE_NAME" || -z "$MACPOWER_RELEASE_TAG" ]]; then
  echo "VERSION must define MACPOWER_VERSION, MACPOWER_BUILD_NUMBER, MACPOWER_RELEASE_NAME, and MACPOWER_RELEASE_TAG." >&2
  exit 1
fi

if [[ "$MODE" != "--bundle-only" && "$MODE" != "bundle-only" ]]; then
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
fi

cd "$ROOT_DIR"
swift build --configuration "$CONFIGURATION"
BUILD_DIR="$(swift build --configuration "$CONFIGURATION" --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$APP_NAME"

if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "Missing app icon: $ICON_SOURCE" >&2
  exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$ICON_SOURCE" "$APP_ICON"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>MacPower.icns</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$MACPOWER_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$MACPOWER_BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>MacPowerReleaseName</key>
  <string>$MACPOWER_RELEASE_NAME</string>
  <key>MacPowerReleaseTag</key>
  <string>$MACPOWER_RELEASE_TAG</string>
</dict>
</plist>
PLIST

/usr/bin/plutil -lint "$INFO_PLIST" >/dev/null

if [[ "$DISTRIBUTION" -eq 1 ]]; then
  /usr/bin/codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"
else
  /usr/bin/codesign --force --sign - --timestamp=none "$APP_BUNDLE"
fi

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

if [[ "$DISTRIBUTION" -eq 1 ]]; then
  SIGNING_DETAILS="$(/usr/bin/codesign -dvv "$APP_BUNDLE" 2>&1)"
  ACTUAL_TEAM_ID="$(printf '%s\n' "$SIGNING_DETAILS" | /usr/bin/awk -F= '/^TeamIdentifier=/{print $2; exit}')"

  if [[ "$ACTUAL_TEAM_ID" != "$EXPECTED_TEAM_ID" ]]; then
    echo "Distribution signature Team ID mismatch: expected $EXPECTED_TEAM_ID, found $ACTUAL_TEAM_ID." >&2
    exit 1
  fi
  if ! printf '%s\n' "$SIGNING_DETAILS" | /usr/bin/grep -Fq "Authority=Developer ID Application:"; then
    echo "Distribution builds must use a Developer ID Application signing identity." >&2
    exit 1
  fi
  if printf '%s\n' "$SIGNING_DETAILS" | /usr/bin/grep -Fq "Signature=adhoc"; then
    echo "Distribution builds must not use an ad hoc signature." >&2
    exit 1
  fi
fi

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

verify_running() {
  local attempts=0
  while (( attempts < 20 )); do
    if pgrep -x "$APP_NAME" >/dev/null; then
      return 0
    fi
    sleep 0.25
    attempts=$((attempts + 1))
  done
  echo "$APP_NAME did not start within 5 seconds" >&2
  return 1
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    exec lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    verify_running
    exec /usr/bin/log stream --info --style compact \
      --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    verify_running
    exec /usr/bin/log stream --info --style compact \
      --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    verify_running
    /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
    echo "Verified local development bundle $APP_BUNDLE and running process $APP_NAME"
    ;;
  --bundle-only|bundle-only)
    if [[ "$DISTRIBUTION" -eq 1 ]]; then
      echo "Built Developer ID-signed distribution candidate $APP_BUNDLE ($MACPOWER_VERSION · $MACPOWER_RELEASE_NAME)"
    else
      echo "Built ad hoc local-development bundle $APP_BUNDLE ($MACPOWER_VERSION · $MACPOWER_RELEASE_NAME)"
    fi
    ;;
esac
