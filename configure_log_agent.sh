#!/bin/bash

echo "Configuring log agent..."
BIN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo ${BIN_DIR}
#LOGSTASH_DIR="$BIN_DIR/../logstash"
INSTALL_DIR=`cd $BIN_DIR/.. && pwd`
LOGSTASH_DIR="$INSTALL_DIR/`ls $BIN_DIR/.. | grep logstash`"
cd -

# Creates monasca-log-agent.service file in etc/systemd/system/ with 0664 permissions
install_system_service() {
    local tmp_service_file="/tmp/monasca-log-agent.service"
    local systemd_dir="/etc/systemd/system"
    local systemd_file="$systemd_dir/monasca-log-agent.service"


    echo "[Unit]
    Description = monasca-log-agent.service

    [Service]
    Group = root
    TimeoutStopSec = infinity
    KillMode = process
    ExecStart = $LOGSTASH_DIR/bin/logstash -f $INSTALL_DIR/conf/agent.conf
    User = root

    [Install]
    WantedBy = multi-user.target" > "${tmp_service_file}"

    sudo cp -f "${tmp_service_file}" "${systemd_file}"
    sudo chown root:root "${systemd_file}"
    sudo chmod 0664 "${systemd_file}"
    sudo systemctl daemon-reload
    rm -rf "${tmp_service_file}"
    sudo systemctl start monasca-log-agent
}

generate_config_file() {
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
    input {" > ${INSTALL_DIR}/conf/agent.conf

    if [ -z "$FILES" ]
    then
        echo -e "No file paths were specified for input -- The agents.conf file
    was successfully created, but you may wish to re-run this command
    with any number of paths for input files at the end of your list
    of arguments"
    else
        for file in $FILES
        do

        echo -e "   file {
        #   add_field => { \"dimensions\" => { \"service\" => \"system\" }}
            path => \"$file\"
          }">> ${INSTALL_DIR}/conf/agent.conf

        done
    fi

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
    }" >> ${INSTALL_DIR}/conf/agent.conf

    echo "agent.conf successfully created in $INSTALL_DIR/conf/"
}

# set default values
HOSTNAME=`hostname`
MONASCA_LOG_API_URL="http://localhost:5607/v3.0"
KEYSTONE_AUTH_URL="http://localhost/identity/v3"
PROJECT_NAME="mini-mon"
USERNAME="monasca-agent"
PASSWORD="password"
USER_DOMAIN_NAME="default"
PROJECT_DOMAIN_NAME="default"
NO_SERVICE=false
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
        *)    # unknown option
        FILES+="$1 " # save it in an array for later
        shift
        ;;
    esac
done

# report to user what values have been set during run
echo MONASCA_LOG_API_URL  = "${MONASCA_LOG_API_URL}"
echo KEYSTONE_AUTH_URL    = "${KEYSTONE_AUTH_URL}"
echo PROJECT_NAME    = "${PROJECT_NAME}"
echo USERNAME  = "${USERNAME}"
echo PASSWORD     = "${PASSWORD}"
echo USER_DOMAIN_NAME    = "${USER_DOMAIN_NAME}"
echo PROJECT_DOMAIN_NAME  = "${PROJECT_DOMAIN_NAME}"
echo DIMENSIONS    = "[ \"hostname:$HOSTNAME\"]"
echo -e INPUT FILE\(S\) PATH\(S\) = "${FILES}"

# Generate agent.conf file with specified values
generate_config_file

# create the monasca-log-agent.service file in /etc/systemd/system/
if [ ! ${NO_SERVICE} ]; then
    install_system_service
fi
