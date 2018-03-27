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

    for protected_file in "${protected_files[@]}"; do
        if [ ! -f "${protected_file}" ]; then
            # No file to backup
            continue
        elif [ "${OVERWRITE_CONF}" = "false" ]; then
            warn "${protected_file} already exists"
            warn "If you want to overwrite it you need to use '--overwrite_conf'"
            # Create backup with preserving permissions
            \cp -f --preserve "${protected_file}" "${protected_file}.backup"
        else
            inf "Existing ${protected_file} file will be overwritten"
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
        "${MON_AGENT_DIR}/supervisor.conf"
        "${MON_SYSTEMD_DIR}/monasca-agent.service"
    )
    protect_overwrite "${conf_files[@]}"

    inf "Running monasca-setup..."
    sudo "${BIN_DIR}/python" "${BIN_DIR}/monasca-setup" "${all_args[@]}" \
        --log_dir "${MON_AGENT_LOG_DIR}"

    protect_restore "${MON_AGENT_DIR}/agent.yaml"
}

function generate_supervisor_config() {
    if [ "${OVERWRITE_CONF}" = "false" ]; then
        protect_restore "${MON_AGENT_DIR}/supervisor.conf"
        return
    fi

    local tmp_conf_file="/tmp/supervisor.conf"
    local supervisor_file="${MON_AGENT_DIR}/supervisor.conf"

    echo "[supervisorctl]
serverurl = unix:///var/tmp/monasca-agent-supervisor.sock

[unix_http_server]
file=/var/tmp/monasca-agent-supervisor.sock

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisord]
minfds = 1024
minprocs = 200
loglevel = info
logfile = ${MON_AGENT_LOG_DIR}/supervisord.log
logfile_maxbytes = 50MB
nodaemon = false
pidfile = /var/run/monasca-agent-supervisord.pid
logfile_backups = 10

[program:collector]
command=${BIN_DIR}/monasca-collector foreground
stdout_logfile=NONE
stderr_logfile=NONE
priority=999
startsecs=2
user=mon-agent
autorestart=true

[program:forwarder]
command=${BIN_DIR}/monasca-forwarder
stdout_logfile=NONE
stderr_logfile=NONE
startsecs=3
priority=998
user=mon-agent
autorestart=true

[program:statsd]
command=${BIN_DIR}/monasca-statsd
stdout_logfile=NONE
stderr_logfile=NONE
startsecs=3
priority=998
user=mon-agent
autorestart=true

[group:monasca-agent]
programs=forwarder,collector,statsd" > "${tmp_conf_file}"

    sudo cp -f "${tmp_conf_file}" "${supervisor_file}"
    sudo chown mon-agent:mon-agent "${supervisor_file}"
    sudo chmod 0664 "${supervisor_file}"
    sudo systemctl daemon-reload
    rm -rf "${tmp_conf_file}"

    inf "${supervisor_file} created"
}

# Creates monasca-metrics-agent.service file in etc/systemd/system/ with 0664 permissions
function create_system_service_file() {
    if [ "${OVERWRITE_CONF}" = "false" ]; then
        protect_restore "${MON_SYSTEMD_DIR}/monasca-agent.service"
        return
    fi

    local tmp_service_file="/tmp/monasca-agent.service"
    local systemd_file="${MON_SYSTEMD_DIR}/monasca-agent.service"


    echo -e "[Unit]
Description=Monasca Agent

[Service]
Type=simple
User=mon-agent
Group=mon-agent
Restart=on-failure
ExecStart=${BIN_DIR}/supervisord -c /etc/monasca/agent/supervisor.conf -n

[Install]
WantedBy=multi-user.target" > "${tmp_service_file}"

    sudo cp -f "${tmp_service_file}" "${systemd_file}"
    sudo chmod 0664 "${systemd_file}"
    sudo systemctl daemon-reload
    rm -rf "${tmp_service_file}"

    inf "${systemd_file} created"
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

generate_supervisor_config

create_system_service_file

set_attributes

inf "Start Monasca Agent daemon"
sudo systemctl stop monasca-agent || true
sudo systemctl enable monasca-agent
sudo systemctl start monasca-agent
