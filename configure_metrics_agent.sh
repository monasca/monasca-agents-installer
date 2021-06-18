#!/bin/bash -e

log() { echo -e "$(date --iso-8601=seconds)" "$1"; }
error() { log "ERROR: $1"; }
warn() { log "WARNING: $1"; }
inf() { log "INFO: $1"; }

BIN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INSTALL_DIR=$( cd "$BIN_DIR/.." && pwd )
MON_SUDOERS_FILE="/etc/sudoers.d/mon-agent"

MON_AGENT_DIR="/etc/monasca/agent"
MON_SYSTEMD_DIR="/etc/systemd/system"
MON_DEFAULT_AGENT_LOG_DIR="/var/log/monasca-agent"

inf "Installation directory: ${INSTALL_DIR}"
inf "Configuring metrics agent..."

if [ ! -e "${MON_SUDOERS_FILE}" ]; then
    echo "mon-agent ALL=(ALL) NOPASSWD:ALL" | sudo tee "${MON_SUDOERS_FILE}" >> /dev/null
fi

sudo mkdir -p /etc/monasca

# Check if file exist, if yes and OVERWRITE_CONF set to false, create backup
# in same folder
function protect_overwrite() {
    local protected_files=("$@")

    if [ "${OVERWRITE_CONF}" = "true" ]; then
        inf "Following files will be overwritten: ${protected_files[*]}"
        return
    fi

    for protected_file in "${protected_files[@]}"; do
        if [ -f "${protected_file}" ]; then
            warn "${protected_file} already exists"
            warn "If you want to overwrite it you need to use '--overwrite_conf'"
            # Create backup with preserving permissions
            \cp -f --preserve "${protected_file}" "${protected_file}.backup"
        fi
    done
}

# Restore file to original location from backup copy if OVERWRITE_CONF is false
function protect_restore() {
    local protected_files=("$@")

    for protected_file in "${protected_files[@]}"; do
        if [ "${OVERWRITE_CONF}" = "false" ]; then
            if [ ! -f "${protected_file}.backup" ]; then
              warn "No backup file ${protected_file}.backup found, skipping"
              return
            fi
            warn "Restoring original ${protected_file}"
            warn "If you want to overwrite it you need to use '--overwrite_conf'"
            \mv -f "${protected_file}.backup" "${protected_file}"
            return
        fi
    done
}

function run_monasca_setup() {
    local all_args=("$@")

    # All this files will be uncoditionaly overwritten by monasca-setup
    # so we are creating they backups if OVERWRITE_CONF is set to false
    conf_files=(
        "${MON_AGENT_DIR}/agent.yaml"
        "${MON_SYSTEMD_DIR}/monasca-agent.service"
    )
    protect_overwrite "${conf_files[@]}"

    inf "Running monasca-setup..."
    sudo "${BIN_DIR}/python" "${BIN_DIR}/monasca-setup" "${all_args[@]}" \
        --log_dir "${MON_AGENT_LOG_DIR}"

    protect_restore "${MON_AGENT_DIR}/agent.yaml"
}


function set_attributes() {

    # Set proper attributes of files
    METRIC_DIRS=("${INSTALL_DIR}" "/etc/monasca" "${MON_AGENT_LOG_DIR}")

    for directory in "${METRIC_DIRS[@]}"
    do
        sudo find "${directory}" -type d -exec chmod 750 {} +
        sudo find "${directory}" -type d -exec chown mon-agent:mon-agent {} +
    done

    inf "Set proper attributes successfully"
}

OVERWRITE_CONF=false
CUSTOM_LOG_DIR=""
MONASCA_SETUP_VARS=()

# check for additional arguments in call to overwrite default values (above)
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        -o|--overwrite_conf)
        OVERWRITE_CONF=true
        shift
        ;;
        --log_dir)
        # We change default to `/var/log/monasca-agent` but allow user
        # to overwrite
        CUSTOM_LOG_DIR="$2"
        shift 2
        ;;
        *)    # other options
        MONASCA_SETUP_VARS+=("${key}")
        shift
        ;;
    esac
done

MON_AGENT_LOG_DIR="${CUSTOM_LOG_DIR:-$MON_DEFAULT_AGENT_LOG_DIR}"

run_monasca_setup "${MONASCA_SETUP_VARS[@]}"

set_attributes

inf "Start Monasca Agent daemon"
sudo systemctl daemon-reload
sudo systemctl stop monasca-agent.target || true
sudo systemctl enable monasca-agent.target
sudo systemctl start monasca-agent.target
