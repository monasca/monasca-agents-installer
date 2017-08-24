#!/bin/bash
source commons

MONASCA_AGENT_TMP_DIR="${TMP_DIR}/monasca-agent"

rm -rf ${MONASCA_AGENT_TMP_DIR}
mkdir -p ${MONASCA_AGENT_TMP_DIR}

virtualenv ${MONASCA_AGENT_TMP_DIR}

${MONASCA_AGENT_TMP_DIR}/bin/pip install monasca-agent

if [ -d "${MAKESELF_DIR}" ]; then
  cd ${MAKESELF_DIR}
  git pull
  cd -
else
  git clone ${MAKESELF_REPO} ${MAKESELF_DIR}
fi

${MAKESELF_DIR}/makeself.sh --notemp ${MONASCA_AGENT_TMP_DIR} monasca-agent.run "Monasca Agents installer" echo "Here goes the configuration step..."

