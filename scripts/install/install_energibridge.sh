#!/usr/bin/env bash
set -euo pipefail

#########################################
# GLOBAL
#########################################

SCRIPT_NAME="install_energibridge"
THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
START_SCRIPT="$THIS_DIR/start_script.sh"
# Bootstap global paths and helpers through the start script
# shellcheck source=/dev/null
source "$START_SCRIPT"
out_msg_separator
out_msg "==================== STARTING $SCRIPT_NAME ===================="
out_msg "Root directory: $ROOT"

#########################################
# READ CONFIG
#########################################
out_msg "READING config"

# PATHS
ENRG_BRG_INSTALL_DIR="$ROOT/$(toml_get "$PROJ_CONFIG_PATH" "enrg_brg_install_dir")"

# EXPERIMENT CONFIG
ENRG_BRG_PLTFM="$(toml_get "$EXP_CONFIG_PATH" "enrg_brg_platform")"

# PROJECT CONFIG
ENRG_BRG_BASE_URL="$(toml_get "$PROJ_CONFIG_PATH" "enrg_brg_base_url")"
ENRG_BRG_VER="$(toml_get "$PROJ_CONFIG_PATH" "enrg_brg_version")"
ENRG_BRG_TARGET="$(toml_get "$PROJ_CONFIG_PATH" "$ENRG_BRG_PLTFM")"

# BUILD VARS FROM CONFIG
ENRG_BRG_GZ="energibridge-v${ENRG_BRG_VER}-${ENRG_BRG_TARGET}.tar.gz"
ENRG_BRG_RELEASE_URL="${ENRG_BRG_BASE_URL}/v${ENRG_BRG_VER}/${ENRG_BRG_GZ}"

#########################################
# INSTALL ENERGIBRIDGE
#########################################
out_msg_separator
out_msg "DOWNLOADING EnergiBridge..."

if [ -e "$ENRG_BRG_INSTALL_DIR/energibridge" ] ; then
  out_msg "EnergiBridge is already installed"
else
  mkdir -p "$ENRG_BRG_INSTALL_DIR"

  TEMP_DIR="$ROOT/temp"
  rm -rf "$TEMP_DIR"
  mkdir "$TEMP_DIR"

  ENRG_BRG_GZ_DIR="${TEMP_DIR}/${ENRG_BRG_GZ}"
  wget \
    "$ENRG_BRG_RELEASE_URL" -P "$TEMP_DIR"

  out_msg "EXTRACTING EnergiBridge..."

  tar -xzf "$ENRG_BRG_GZ_DIR" -C "$ENRG_BRG_INSTALL_DIR"
  sudo chmod +x "$ENRG_BRG_INSTALL_DIR/energibridge"

  out_msg "COMPLETED EnergiBridge installation"
fi

out_msg "==================== ENDING $SCRIPT_NAME ===================="
