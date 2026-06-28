#!/bin/bash
set -e

REPO="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$REPO/config"
BOARD="seeeduino_xiao_ble"
SHARED="$HOME/src/zmk-workspace-dya"
MODULES_COMMON="$HOME/src/zmk-modules-mona2"
MODULES_DYA="$HOME/src/zmk-modules-dya"
VENV="$SHARED/.venv"

export ZEPHYR_BASE="$SHARED/zephyr"

EXTRA_MODULES="$MODULES_COMMON/zmk-pmw3610-driver"
EXTRA_MODULES="$EXTRA_MODULES;$MODULES_COMMON/zmk-rgbled-widget"
EXTRA_MODULES="$EXTRA_MODULES;$MODULES_COMMON/zmk-input-processor-keybind"
EXTRA_MODULES="$EXTRA_MODULES;$MODULES_DYA/zmk-module-ble-management"
EXTRA_MODULES="$EXTRA_MODULES;$MODULES_DYA/zmk-module-settings-rpc"
EXTRA_MODULES="$EXTRA_MODULES;$MODULES_DYA/zmk-module-runtime-input-processor"
EXTRA_MODULES="$EXTRA_MODULES;$MODULES_DYA/zmk-behavior-runtime-sensor-rotate"

source "$VENV/bin/activate"
cd "$SHARED"

TARGET=${1:-all}

build_left() {
  echo "=== Building LEFT (DYA) ==="
  west build -d "$REPO/build/left" -s zmk/app -b $BOARD --pristine \
    -- -DSHIELD="mona2_l rgbled_adapter" \
       -DZMK_CONFIG="$CONFIG_DIR" \
       -DBOARD_ROOT="$REPO" \
       -DZMK_EXTRA_MODULES="$EXTRA_MODULES"
  cp "$REPO/build/left/zephyr/zmk.uf2" "$REPO/mona2_dya_left.uf2"
  echo "=> mona2_dya_left.uf2"
}

build_right() {
  echo "=== Building RIGHT (DYA + Studio RPC) ==="
  west build -d "$REPO/build/right" -s zmk/app -b $BOARD --pristine \
    -- -DSHIELD="mona2_r rgbled_adapter" \
       -DZMK_CONFIG="$CONFIG_DIR" \
       -DBOARD_ROOT="$REPO" \
       -DZMK_EXTRA_MODULES="$EXTRA_MODULES"
  cp "$REPO/build/right/zephyr/zmk.uf2" "$REPO/mona2_dya_right.uf2"
  echo "=> mona2_dya_right.uf2"
}

case "$TARGET" in
  left)  build_left ;;
  right) build_right ;;
  all)   build_left; build_right ;;
  *)     echo "Usage: $0 [left|right|all]"; exit 1 ;;
esac

echo "=== Done ==="
