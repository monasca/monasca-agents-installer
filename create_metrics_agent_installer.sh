#!/bin/bash
source commons

MONASCA_AGENT_TMP_DIR="${TMP_DIR}/monasca-agent"

mkdir -p ${MONASCA_AGENT_TMP_DIR}

virtualenv ${MONASCA_AGENT_TMP_DIR}

${MONASCA_AGENT_TMP_DIR}/bin/pip install monasca-agent
cp configure_metrics_agent.sh ${MONASCA_AGENT_TMP_DIR}/bin

if [ -d "${MAKESELF_DIR}" ]; then
    cd ${MAKESELF_DIR}
    git pull
    cd -
else
    git clone ${MAKESELF_REPO} ${MAKESELF_DIR}
fi

cat metrics_agent_help_header > metrics_agent_help_header.tmp
${MONASCA_AGENT_TMP_DIR}/bin/python ${MONASCA_AGENT_TMP_DIR}/bin/monasca-setup --help \
    >> metrics_agent_help_header.tmp
#comment

${MAKESELF_DIR}/makeself.sh --notemp \
                            --help-header metrics_agent_help_header.tmp \
                            ${MONASCA_AGENT_TMP_DIR} \
                            monasca-agent.run \
                            "Monasca Agents installer" \
                            ./bin/configure_metrics_agent.sh

rm -rf ${MONASCA_AGENT_TMP_DIR}
