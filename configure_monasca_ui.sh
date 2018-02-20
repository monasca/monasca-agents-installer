#!/bin/bash

log() { echo -e "$(date --iso-8601=seconds)" "$1"; }
error() { log "ERROR: $1"; }
warn() { log "WARNING: $1"; }
inf() { log "INFO: $1"; }

inf "Configuring monasca-ui Horizon plugin..."
BIN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INSTALL_DIR="$(cd "$BIN_DIR/.." && pwd)"

function process_config() {
  LOCAL_SETTINGS_FILE=$(find "${INSTALL_DIR}" -name local_settings.py)
  local chrlen=${#LOCAL_SETTINGS_FILE}
  if [ "$chrlen" -gt 0 ]; then
    if [ "${OVERWRITE_CONF}" = "false" ]; then
      warn "${LOCAL_SETTINGS_FILE} already exists"
      warn "If you want to overwrite it you need to use '--overwrite_conf'"
      return
    else
      inf "Existing ${LOCAL_SETTINGS_FILE} file will be overwritten"
    fi
  fi

  LOCAL_SETTINGS_EX=$(find "${INSTALL_DIR}" -name local_settings.py.example)
  if [ -f "${LOCAL_SETTINGS_EX}" ]; then
    LOCAL_SETTINGS_FILE="${LOCAL_SETTINGS_EX%.example}"
    mv "${LOCAL_SETTINGS_EX}" "${LOCAL_SETTINGS_FILE}"
  else
    error "No ${LOCAL_SETTINGS_EX} found to replace local_settings.py"
    exit 1
  fi

  warn "Make sure to update monasca-ui configuration before restarting Horizon. Configuration file: ${LOCAL_SETTINGS_FILE}"
}

OVERWRITE_CONF=false

# Check for additional arguments in call to overwrite default values (above)
while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in
    -o|--overwrite_conf)
    OVERWRITE_CONF=true
    shift
    ;;
    *)    # other options
    shift
    ;;
  esac
done

process_config
