#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Kinesis"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.build/DerivedData"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
XCODEBUILD=(/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild
  -project "$ROOT_DIR/Kinesis.xcodeproj"
  -scheme "$APP_NAME"
  -configuration Debug
  -destination "platform=macOS"
  -derivedDataPath "$DERIVED_DATA"
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO
)

build_app() {
  "${XCODEBUILD[@]}" build
}

test_app() {
  "${XCODEBUILD[@]}" test
}

run_python_tests() {
  if [[ -x "$ROOT_DIR/.venv/bin/python" ]]; then
    "$ROOT_DIR/.venv/bin/python" -m pytest "$ROOT_DIR/cv_helper/tests"
  else
    python3 -m pytest "$ROOT_DIR/cv_helper/tests"
  fi
}

open_app() {
  if [[ ! -d "$APP_BUNDLE" ]]; then
    echo "Built app not found at $APP_BUNDLE" >&2
    exit 1
  fi
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  KINESIS_PROJECT_ROOT="$ROOT_DIR" /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    build_app
    open_app
    ;;
  --verify|verify)
    build_app
    open_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    echo "$APP_NAME is running."
    ;;
  --logs|logs)
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --test|test)
    test_app
    run_python_tests
    ;;
  *)
    echo "usage: $0 [run|--verify|--logs|--test]" >&2
    exit 2
    ;;
esac
