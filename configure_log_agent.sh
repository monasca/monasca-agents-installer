#!/bin/bash -e

log() { echo -e "$(date --iso-8601=seconds)" "$1"; }
error() { log "ERROR: $1"; }
warn() { log "WARNING: $1"; }
inf() { log "INFO: $1"; }

BIN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INSTALL_DIR="$(cd "$BIN_DIR/.." && pwd)"
LOGSTASH_DIR="$INSTALL_DIR/$(ls "$BIN_DIR/.." | grep logstash)"

MON_LOG_AGENT_LOG_DIR="/var/log/monasca-log-agent"

inf "Installation directory: ${INSTALL_DIR}"
inf "Configuring log agent..."

# Creates monasca-log-agent.service file in etc/systemd/system/ with 0664 permissions
create_system_service_file() {
    local tmp_service_file="/tmp/monasca-log-agent.service"
    local systemd_dir="/etc/systemd/system"
    local systemd_file="$systemd_dir/monasca-log-agent.service"

    if [ -f "${systemd_file}" ]; then
        if [ "$OVERWRITE_CONF" = "false" ]; then
            warn "Service file already exists"
            warn "If you want to overwrite it you need to use '--overwrite_conf'"
            return
        else
            inf "Existing service file will be overwritten"
        fi
    fi

    inf "Creating new service file"

    echo "[Unit]
    Description = monasca-log-agent.service

    [Service]
    Group = root
    TimeoutStopSec = infinity
    KillMode = process
    ExecStart = $LOGSTASH_DIR/bin/logstash --config $INSTALL_DIR/conf/agent.conf --log ${MON_LOG_AGENT_LOG_DIR}/log-agent.log
    User = root

    [Install]
    WantedBy = multi-user.target" > "${tmp_service_file}"

    sudo cp -f "${tmp_service_file}" "${systemd_file}"
    sudo chown root:root "${systemd_file}"
    sudo chmod 0664 "${systemd_file}"
    sudo systemctl daemon-reload
    rm -rf "${tmp_service_file}"

    # Create folder and file for logs with proper permissions
    sudo mkdir -p "${MON_LOG_AGENT_LOG_DIR}"
    sudo chmod 0750 "${MON_LOG_AGENT_LOG_DIR}"
    sudo touch "${MON_LOG_AGENT_LOG_DIR}/log-agent.log"
    sudo chmod 0644 "${MON_LOG_AGENT_LOG_DIR}/log-agent.log"

    inf "${systemd_file} created"
}

generate_specific_config_file() {
    if [ -f "${INSTALL_DIR}/conf/agent.conf" ]; then
        if [ "$OVERWRITE_CONF" = "false" ]; then
            warn "${INSTALL_DIR}/conf/agent.conf already exists"
            warn "If you want to overwrite it you need to use '--overwrite_conf'"
            return
        else
            inf "Existing agent.conf file will be overwritten"
        fi
    fi

    echo -e "#
    # Copyright 2017 FUJITSU LIMITED
    #
    # Licensed under the Apache License, Version 2.0 (the \"License\");
    # you may not use this file except in compliance with the License.
    # You may obtain a copy of the License at
    #
    #    http://www.apache.org/licenses/LICENSE-2.0
    #
    # Unless required by applicable law or agreed to in writing, software
    # distributed under the License is distributed on an \"AS IS\" BASIS,
    # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
    # implied.
    # See the License for the specific language governing permissions and
    # limitations under the License.
    #
    input {" > "${INSTALL_DIR}/conf/agent.conf"

    for file in $FILES
    do
        if [ ! -d "$file" ]; then
            echo -e "   file {
            #   add_field => { \"dimensions\" => { \"service\" => \"system\" }}
                path => \"$file\"
              }">> "${INSTALL_DIR}/conf/agent.conf"
        else
            inf "$file is a directory. Only files can be monitored - skipping."
        fi
    done

    echo -e "}

    output {
      monasca_log_api {
        monasca_log_api_url => \"$MONASCA_LOG_API_URL\"
        keystone_api_url => \"$KEYSTONE_AUTH_URL\"
        project_name => \"$PROJECT_NAME\"
        username => \"$USERNAME\"
        password => \"$PASSWORD\"
        user_domain_name => \"$USER_DOMAIN_NAME\"
        project_domain_name => \"$PROJECT_DOMAIN_NAME\"
        dimensions => [ \"hostname:$HOSTNAME\" ]
      }
    }" >> "${INSTALL_DIR}/conf/agent.conf"

    inf "agent.conf successfully created in $INSTALL_DIR/conf/"
}

generate_default_config_file() {
    if [ -f "${INSTALL_DIR}/conf/agent.conf" ]; then
        if [ "$OVERWRITE_CONF" = "false" ]; then
            warn "${INSTALL_DIR}/conf/agent.conf already exists"
            warn "If you want to overwrite it you need to use '--overwrite_conf'"
            return
        else
            inf "Existing agent.conf file will be overwritten"
        fi
    fi

    sudo python "$BIN_DIR/set_config.py" \
        --tmp_config "$INSTALL_DIR/conf/agent.conf.j2" \
        --config "$INSTALL_DIR/conf/agent.conf" \
        --input_ini "$INSTALL_DIR/conf/input.ini" \
        --filter_ini "$INSTALL_DIR/conf/filter.ini" \
        --monasca_log_api_url "$MONASCA_LOG_API_URL" \
        --keystone_auth_url "$KEYSTONE_AUTH_URL" \
        --project_name "$PROJECT_NAME" \
        --username "$USERNAME" \
        --password "$PASSWORD" \
        --user_domain_name "$USER_DOMAIN_NAME" \
        --project_domain_name "$PROJECT_DOMAIN_NAME" \
        --hostname "$HOSTNAME"

    inf "INFO: No file paths were specified for input -- The default
agents.conf file was successfully created in $INSTALL_DIR/conf/, but you may
wish to re-run this command with any number of paths for input files at the end
of your list of arguments"
}

# set default values
HOSTNAME=$(hostname)
MONASCA_LOG_API_URL="http://localhost:5607/v3.0"
KEYSTONE_AUTH_URL="http://localhost/identity/v3"
PROJECT_NAME="mini-mon"
USERNAME="monasca-agent"
PASSWORD="password"
USER_DOMAIN_NAME="default"
PROJECT_DOMAIN_NAME="default"
NO_SERVICE=false
OVERWRITE_CONF=false
FILES=""

# check for additional arguments in call to override default values (above)
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        -m|--monasca_log_api_url)
        MONASCA_LOG_API_URL="$2"
        shift 2
        ;;
        -k|--keystone_auth_url)
        KEYSTONE_AUTH_URL="$2"
        shift 2
        ;;
        -n|--project_name)
        PROJECT_NAME="$2"
        shift 2
        ;;
        -u|--username)
        USERNAME="$2"
        shift 2
        ;;
        -p|--password)
        PASSWORD="$2"
        shift 2
        ;;
        -d|--user_domain_name)
        USER_DOMAIN_NAME="$2"
        shift 2
        ;;
        -r|--project_domain_name)
        PROJECT_DOMAIN_NAME="$2"
        shift 2
        ;;
        --no_service)
        NO_SERVICE=true
        shift
        ;;
        -h|--hostname)
        HOSTNAME="$2"
        shift 2
        ;;
        -o|--overwrite_conf)
        OVERWRITE_CONF=true
        shift
        ;;
        *)    # unknown option
        FILES+="$1 " # save it in an array for later
        shift
        ;;
    esac
done

# report to user what values have been set during run
echo MONASCA_LOG_API_URL  = "${MONASCA_LOG_API_URL}"
echo KEYSTONE_AUTH_URL    = "${KEYSTONE_AUTH_URL}"
echo PROJECT_NAME         = "${PROJECT_NAME}"
echo USERNAME             = "${USERNAME}"
echo PASSWORD             = "${PASSWORD}"
echo USER_DOMAIN_NAME     = "${USER_DOMAIN_NAME}"
echo PROJECT_DOMAIN_NAME  = "${PROJECT_DOMAIN_NAME}"
echo DIMENSIONS           = "[ \"hostname:$HOSTNAME\"]"
echo OVERWRITE_CONF       = "${OVERWRITE_CONF}"
echo -e INPUT FILE\(S\) PATH\(S\) = "${FILES}"

# Generate agent.conf file
if [ -z "$FILES" ]; then
    generate_default_config_file
else
    generate_specific_config_file
fi

# Create the monasca-log-agent.service file in /etc/systemd/system/
if [ ${NO_SERVICE} = false ]; then
    create_system_service_file

    inf "Start Monasca Log Agent daemon"
    sudo systemctl stop monasca-log-agent || true
    sudo systemctl enable monasca-log-agent
    sudo systemctl start monasca-log-agent
fi
