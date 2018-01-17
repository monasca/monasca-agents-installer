#!/bin/bash -e
source commons

# takes the first argument as the version. Defaults to the latest version
# of monasca-ui if no argument is specified.
MONASCA_UI_VERSION=${1:-`pip search monasca-ui | grep monasca-ui | \
                            awk '{print $2}' | sed 's|(||' | sed 's|)||'`}
UPPER_CONSTRAINT_FILE=${2:-""}

MONASCA_UI_TMP_DIR="${TMP_DIR}/monasca-ui"

mkdir -p ${MONASCA_UI_TMP_DIR}

virtualenv ${MONASCA_UI_TMP_DIR}

if [ -z "${UPPER_CONSTRAINT_FILE}" ]; then
    ${MONASCA_UI_TMP_DIR}/bin/pip install monasca-ui==$MONASCA_UI_VERSION
else
    ${MONASCA_UI_TMP_DIR}/bin/pip install -c ${UPPER_CONSTRAINT_FILE} monasca-ui==$MONASCA_UI_VERSION
fi
virtualenv --relocatable ${MONASCA_UI_TMP_DIR}

cp configure_monasca_ui.sh ${MONASCA_UI_TMP_DIR}/bin
LOCAL_SETTINGS_FILE=$(find "${MONASCA_UI_TMP_DIR}" -name local_settings.py)
sed -i -e "s/192.168.10.4:5601/<kibana_host>:5601/g" "${LOCAL_SETTINGS_FILE}"

if [ -d "${MAKESELF_DIR}" ]; then
    cd ${MAKESELF_DIR}
    git pull
    cd -
else
    git clone ${MAKESELF_REPO} ${MAKESELF_DIR}
fi

cat monasca_ui_help_header > monasca_ui_help_header.tmp

${MAKESELF_DIR}/makeself.sh --notemp \
                            --help-header monasca_ui_help_header.tmp \
                            ${MONASCA_UI_TMP_DIR} \
                            monasca-ui-${MONASCA_UI_VERSION}.run \
                            "Monasca UI installer" \
                            ./bin/configure_monasca_ui.sh

rm -rf ${MONASCA_UI_TMP_DIR}
