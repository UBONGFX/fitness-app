#!/bin/bash
# Tests laufen lassen — in der Stufe, die zur Änderung passt.
#
#   ./Tools/test.sh            Unit-Tests (Sekunden)
#   ./Tools/test.sh ui         UI-Tests ohne Screenshot-Suite
#   ./Tools/test.sh all        Unit + UI
#   ./Tools/test.sh shots      nur die Screenshot-Suite
#   ./Tools/test.sh <Suite>    eine einzelne Suite, z. B. HomeUITests
#
# Die Unit-Tests sind der Normalfall: sie decken die ganze Rechenlogik ab und
# brauchen keinen sichtbaren Simulator. UI-Tests kosten pro Test einen App-Start
# und sind deshalb um zwei Größenordnungen langsamer — die lohnen sich, wenn am
# Bildschirm etwas geändert wurde, nicht nach jeder Zeile.
set -euo pipefail
cd "$(dirname "$0")/.."

SIM_ID="${FITNESS_SIM_ID:-}"
if [ -z "$SIM_ID" ]; then
  SIM_ID=$(xcrun simctl list devices available --json | python3 -c '
import json, sys
for devices in json.load(sys.stdin)["devices"].values():
    for device in devices:
        if "iPhone" in device["name"]:
            print(device["udid"])
            raise SystemExit
raise SystemExit("No available iPhone simulator")
')
fi
DERIVED="build3"

# Drei Worker, nicht mehr. Jeder klont einen eigenen Simulator; bei fünf sind auf
# dieser Maschine reproduzierbar zwei Runner gar nicht erst hochgekommen
# ("Timed out waiting for AX loaded notification"), und schneller war es nicht —
# der Flaschenhals ist der App-Start pro Test, nicht die CPU.
WORKERS="${FITNESS_WORKERS:-3}"

MODE="${1:-unit}"
ARGS=()

case "$MODE" in
  unit)
    ARGS+=(-only-testing:FitnessAppTests)
    PARALLEL=0
    ;;
  ui)
    ARGS+=(-only-testing:FitnessAppUITests -skip-testing:FitnessAppUITests/ScreenshotCapture)
    PARALLEL=1
    ;;
  all)
    ARGS+=(-skip-testing:FitnessAppUITests/ScreenshotCapture)
    PARALLEL=1
    ;;
  shots)
    ARGS+=(-only-testing:FitnessAppUITests/ScreenshotCapture)
    PARALLEL=1
    ;;
  *)
    # Einzelne Suite oder einzelner Test, z. B. HomeUITests oder
    # HomeUITests/testTheAppOpensOnTheOverview
    if [[ "$MODE" == *UITests* ]]; then
      ARGS+=("-only-testing:FitnessAppUITests/$MODE")
    else
      ARGS+=("-only-testing:FitnessAppTests/$MODE")
    fi
    PARALLEL=0
    ;;
esac

if [ "$PARALLEL" = "1" ]; then
  ARGS+=(-parallel-testing-enabled YES -maximum-parallel-testing-workers "$WORKERS")
  echo "→ $MODE, $WORKERS Worker"
else
  ARGS+=(-parallel-testing-enabled NO)
  echo "→ $MODE"
fi

# Fester Pfad je Lauf, plus eine Kopie unter last-test.log: nach einem Fehlschlag
# will man das Log wiederfinden, ohne es unter zwanzig Temp-Dateien zu suchen.
# Der Prozessname im Pfad ist nötig, weil zwei gleichzeitige Läufe sich sonst
# gegenseitig überschreiben — und man dann das Ergebnis des falschen liest.
mkdir -p build3
LOG="build3/test-${MODE//\//-}-$$.log"
START=$(date +%s)

set +e
xcodebuild -project FitnessApp.xcodeproj -scheme FitnessApp \
  -destination "id=$SIM_ID" -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO "${ARGS[@]}" test > "$LOG" 2>&1
STATUS=$?
set -e

ELAPSED=$(( $(date +%s) - START ))
PASSED=$(grep -ciE "Test case .* passed|✔ Test .* passed" "$LOG" || true)

echo
if [ "$STATUS" -eq 0 ]; then
  cp "$LOG" build3/last-test.log
  echo "✓ $PASSED Tests grün in ${ELAPSED}s"
else
  cp "$LOG" build3/last-test.log
  echo "✗ Fehlgeschlagen nach ${ELAPSED}s ($PASSED grün)"
  echo
  grep -E "error: -\[|✘ Test .* failed|Fatal error" "$LOG" | head -20
  echo
  echo "Volles Log: $LOG"
fi
exit $STATUS
