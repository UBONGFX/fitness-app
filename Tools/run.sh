#!/bin/bash
# Baut die App und startet sie — im Simulator oder auf dem iPhone.
#
#   ./Tools/run.sh            Simulator (Standard)
#   ./Tools/run.sh sim        Simulator
#   ./Tools/run.sh phone      angeschlossenes iPhone
#
# Das iPhone braucht eine Signierung mit dem Developer-Team; die Installation
# läuft danach sieben Tage, weil es ein kostenloses Personal Team ist. Danach
# einfach nochmal `./Tools/run.sh phone`.

set -euo pipefail
cd "$(dirname "$0")/.."

BUNDLE_ID="com.jordiisken.fitnessapp"
SCHEME="FitnessApp"
TARGET="${1:-sim}"
if [ -f .private/signing.env ]; then
  source .private/signing.env
fi
DEFAULT_HEIGHT="${FITNESS_DEFAULT_HEIGHT_METERS:-1.75}"

# Projektdatei aus project.yml erzeugen, falls XcodeGen da ist.
command -v xcodegen >/dev/null && xcodegen generate >/dev/null

case "$TARGET" in
  sim)
    # Erstes verfügbares iPhone nehmen, nicht über den Namen suchen — unter
    # Xcode 27 ist die Namensauflösung unzuverlässig.
    UDID=$(xcrun simctl list devices available --json \
      | python3 -c "
import sys, json
data = json.load(sys.stdin)['devices']
for runtime, devices in sorted(data.items(), reverse=True):
    for device in devices:
        if 'iPhone' in device['name']:
            print(device['udid']); raise SystemExit
raise SystemExit('kein iPhone-Simulator gefunden')")

    echo "▸ Simulator $UDID starten"
    xcrun simctl boot "$UDID" 2>/dev/null || true
    xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true

    # Unter Xcode 27 heißt die Simulator-Oberfläche DeviceHub.
    open "/Applications/Xcode.app/Contents/Applications/DeviceHub.app" 2>/dev/null || true

    echo "▸ Bauen"
    xcodebuild -project FitnessApp.xcodeproj -scheme "$SCHEME" \
      -destination "id=$UDID" -derivedDataPath build2 \
      CODE_SIGNING_ALLOWED=NO INFOPLIST_KEY_FitnessDefaultHeightMeters="$DEFAULT_HEIGHT" build | tail -1

    echo "▸ Installieren und starten"
    xcrun simctl install "$UDID" build2/Build/Products/Debug-iphonesimulator/FitnessApp.app
    xcrun simctl launch "$UDID" "$BUNDLE_ID"
    ;;

  phone)
    # Keep the signing team local: the public project contains no personal
    # provisioning identifier. An environment variable takes precedence.
    TEAM_ID="${FITNESS_DEVELOPMENT_TEAM:-}"
    if [ -z "$TEAM_ID" ]; then
      echo "Set FITNESS_DEVELOPMENT_TEAM or .private/signing.env for phone builds." >&2
      exit 1
    fi
    # Der Status heißt je nach Verbindungsart "connected", "available" oder
    # "available (paired)" — alle drei taugen zum Installieren.
    UDID=$(xcrun devicectl list devices 2>/dev/null \
      | awk '/physical/ && (/connected/ || /available/) {for (i=1; i<=NF; i++) if ($i ~ /^[0-9A-F]{8}-/) {print $i; exit}}')

    if [ -z "$UDID" ]; then
      echo "Kein verbundenes iPhone gefunden." >&2
      echo "Per Kabel anschließen, entsperren und ggf. 'Diesem Computer vertrauen' bestätigen." >&2
      exit 1
    fi

    echo "▸ Signiert bauen für $UDID"
    xcodebuild -project FitnessApp.xcodeproj -scheme "$SCHEME" \
      -destination "id=$UDID" -derivedDataPath build3 \
      -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM_ID" \
      INFOPLIST_KEY_FitnessDefaultHeightMeters="$DEFAULT_HEIGHT" build | tail -1

    echo "▸ Installieren"
    xcrun devicectl device install app --device "$UDID" \
      build3/Build/Products/Debug-iphoneos/FitnessApp.app >/dev/null

    echo "▸ Starten"
    xcrun devicectl device process launch --device "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 \
      || echo "  (nicht automatisch gestartet — vom Homescreen öffnen)"

    echo ""
    echo "Beim allerersten Mal: Einstellungen → Allgemein → VPN & Geräteverwaltung"
    echo "→ Entwickler-App → vertrauen."
    ;;

  *)
    echo "Aufruf: ./Tools/run.sh [sim|phone]" >&2
    exit 1
    ;;
esac
