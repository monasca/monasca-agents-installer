#!/bin/bash -e

echo "Configuring agent..."
BIN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INSTALL_DIR=`cd $BIN_DIR/.. && pwd`

sudo mkdir -p /etc/monasca

sudo ${BIN_DIR}/python ${BIN_DIR}/monasca-setup $@

generate_supervisor_config() {
    local tmp_conf_file="/tmp/supervisor.conf"
    local agent_dir="/etc/monasca/agent"
    local supervisor_file="$agent_dir/supervisor.conf"

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
logfile = /var/log/monasca/agent/supervisord.log
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
    sudo chown root:root "${supervisor_file}"
    sudo chmod 0664 "${supervisor_file}"
    sudo systemctl daemon-reload
    rm -rf "${tmp_conf_file}"

    echo "/etc/monasca/agent/supervisor.conf created"
}

# Creates monasca-metrics-agent.service file in etc/systemd/system/ with 0664 permissions
install_system_service() {
    local tmp_service_file="/tmp/monasca-agent.service"
    local systemd_dir="/etc/systemd/system"
    local systemd_file="$systemd_dir/monasca-agent.service"


    echo -e "[Unit]
Description=Monasca Agent

[Service]
Type=simple
User=root
Group=root
Restart=on-failure
ExecStart=${BIN_DIR}/supervisord -c /etc/monasca/agent/supervisor.conf -n

[Install]
WantedBy=multi-user.targetvagrant" > "${tmp_service_file}"

    sudo cp -f "${tmp_service_file}" "${systemd_file}"
    sudo chown root:root "${systemd_file}"
    sudo chmod 0664 "${systemd_file}"
    sudo systemctl daemon-reload
    rm -rf "${tmp_service_file}"
    sudo systemctl start monasca-agent

    echo "/etc/systemd/system/monasca-agent.service created"
}

generate_supervisor_config

install_system_service
