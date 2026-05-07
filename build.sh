#!/bin/bash
set -e

REPO="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$REPO/config"
BOARD="seeeduino_xiao_ble"
SHARED="$HOME/src/zmk-workspace"
MODULES="$HOME/src/zmk-modules-mona2"
VENV="$SHARED/.venv"

export ZEPHYR_BASE="$SHARED/zephyr"
EXTRA_MODULES="$MODULES/zmk-pmw3610-driver"
EXTRA_MODULES="$EXTRA_MODULES;$MODULES/zmk-rgbled-widget"
EXTRA_MODULES="$EXTRA_MODULES;$MODULES/zmk-input-processor-keybind"

source "$VENV/bin/activate"
cd "$SHARED"

TARGET=${1:-all}

build_left() {
  echo "=== Building LEFT ==="
  west build -d "$REPO/build/left" -s zmk/app -b $BOARD --pristine \
    -- -DSHIELD="mona2_l rgbled_adapter" \
       -DZMK_CONFIG="$CONFIG_DIR" \
       -DBOARD_ROOT="$REPO" \
       -DZMK_EXTRA_MODULES="$EXTRA_MODULES"
  cp "$REPO/build/left/zephyr/zmk.uf2" "$REPO/mona2_left.uf2"
  echo "=> mona2_left.uf2"
}

build_right() {
  echo "=== Building RIGHT ==="
  west build -d "$REPO/build/right" -s zmk/app -b $BOARD --pristine \
    -- -DSHIELD="mona2_r rgbled_adapter" \
       -DZMK_CONFIG="$CONFIG_DIR" \
       -DBOARD_ROOT="$REPO" \
       -DZMK_EXTRA_MODULES="$EXTRA_MODULES" \
       -DCONFIG_ZMK_STUDIO=y
  cp "$REPO/build/right/zephyr/zmk.uf2" "$REPO/mona2_right.uf2"
  echo "=> mona2_right.uf2"
}

case "$TARGET" in
  left)  build_left ;;
  right) build_right ;;
  all)   build_left; build_right ;;
  *)     echo "Usage: $0 [left|right|all]"; exit 1 ;;
esac

echo "=== Done ==="
