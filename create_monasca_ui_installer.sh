#!/bin/bash -e
source commons

# takes the first argument as the version. Defaults to the latest version
# of monasca-ui if no argument is specified.
MONASCA_UI_VERSION=${1:-`pip search monasca-ui | grep monasca-ui | \
                            awk '{print $2}' | sed 's|(||' | sed 's|)||'`}

MONASCA_UI_TMP_DIR="${TMP_DIR}/monasca-ui"

mkdir -p ${MONASCA_UI_TMP_DIR}

virtualenv ${MONASCA_UI_TMP_DIR}
${MONASCA_UI_TMP_DIR}/bin/pip install monasca-ui==$MONASCA_UI_VERSION
virtualenv --relocatable ${MONASCA_UI_TMP_DIR}

cp configure_monasca_ui.sh ${MONASCA_UI_TMP_DIR}/bin

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
