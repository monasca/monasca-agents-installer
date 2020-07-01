#!/bin/bash -e

# shellcheck disable=SC1091
source commons

log() { echo -e "$(date --iso-8601=seconds)" "$1"; }
error() { log "ERROR: $1"; }
warn() { log "WARNING: $1"; }
inf() { log "INFO: $1"; }

# takes the first argument as the version. Defaults to the latest version
# of monasca-agent if no argument is specified.
LOGSTASH_VERSION=${1:-2.4.1}
LOGSTASH_OUTPUT_MONASCA_LOG_API_VERSION=${2:-1.0.3}

LOG_AGENT_TMP_DIR="${TMP_DIR}/monasca-log-agent"

inf "Downloading Monasca Log Agent"
inf "Logstash version: ${LOGSTASH_VERSION}"
inf "Logstash output Monasca Log API plugin version: ${LOGSTASH_OUTPUT_MONASCA_LOG_API_VERSION}"
mkdir -p "${LOG_AGENT_TMP_DIR}"/bin
wget https://artifacts.elastic.co/downloads/logstash/logstash-"${LOGSTASH_VERSION}".tar.gz -N -P "${TMP_DIR}"/
wget https://rubygems.org/downloads/logstash-output-monasca_log_api-"${LOGSTASH_OUTPUT_MONASCA_LOG_API_VERSION}".gem \
    -N -P "${TMP_DIR}"/

tar xf "${TMP_DIR}"/logstash-"${LOGSTASH_VERSION}".tar.gz -C "${LOG_AGENT_TMP_DIR}"

mkdir -p "${LOG_AGENT_TMP_DIR}"/conf

"${LOG_AGENT_TMP_DIR}"/logstash-"${LOGSTASH_VERSION}"/bin/logstash-plugin \
    install "${TMP_DIR}"/logstash-output-monasca_log_api-"${LOGSTASH_OUTPUT_MONASCA_LOG_API_VERSION}".gem
cp configure_log_agent.sh "${LOG_AGENT_TMP_DIR}"/bin
cp set_config.py "${LOG_AGENT_TMP_DIR}"/bin
cp agent.conf.j2 "${LOG_AGENT_TMP_DIR}"/conf
cp input.ini "${LOG_AGENT_TMP_DIR}"/conf
cp filter.ini "${LOG_AGENT_TMP_DIR}"/conf

inf "Downloading latest Makeself"
if [ -d "${MAKESELF_DIR}" ]; then
    cd "${MAKESELF_DIR}" || exit
    git pull
    cd -
else
    git clone "${MAKESELF_REPO}" "${MAKESELF_DIR}"
fi

cat log_agent_help_header > log_agent_help_header.tmp

inf "Creating Monasca Log Agent installer file"
"${MAKESELF_DIR}"/makeself.sh --notemp \
                              --tar-quietly \
                              --help-header log_agent_help_header.tmp \
                              "${LOG_AGENT_TMP_DIR}" \
                              log-agent-"${LOGSTASH_VERSION}"_"${LOGSTASH_OUTPUT_MONASCA_LOG_API_VERSION}".run \
                              "Monasca Log Agent installer" \
                              ./bin/configure_log_agent.sh

inf "Removing temporary files"
rm -rf "${LOG_AGENT_TMP_DIR}"

inf "Process of creating Monasca Log Agent installer ended successfully"
