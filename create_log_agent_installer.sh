#!/bin/bash -e
source commons

# takes the first argument as the version. Defaults to the latest version
# of monasca-agent if no argument is specified.
LOGSTASH_VERSION=${1:-2.4.1}

LOG_AGENT_TMP_DIR="${TMP_DIR}/monasca-log-agent"

mkdir -p ${LOG_AGENT_TMP_DIR}/bin
wget https://download.elastic.co/logstash/logstash/logstash-${LOGSTASH_VERSION}.tar.gz -N -P ${TMP_DIR}/

tar xf ${TMP_DIR}/logstash-${LOGSTASH_VERSION}.tar.gz -C ${LOG_AGENT_TMP_DIR}
cp configure_log_agent.sh ${LOG_AGENT_TMP_DIR}/bin

if [ -d "${MAKESELF_DIR}" ]; then
    cd ${MAKESELF_DIR}
    git pull
    cd -
else
    git clone ${MAKESELF_REPO} ${MAKESELF_DIR}
fi

cat log_agent_help_header > log_agent_help_header.tmp

${MAKESELF_DIR}/makeself.sh --notemp \
                            --help-header log_agent_help_header.tmp \
                            ${LOG_AGENT_TMP_DIR} \
                            log-agent-${LOGSTASH_VERSION}.run \
                            "Monasca Log Agent installer" \
                            ./bin/configure_log_agent.sh

rm -rf ${LOG_AGENT_TMP_DIR}
