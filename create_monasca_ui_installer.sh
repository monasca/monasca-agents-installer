#!/bin/bash -e

# shellcheck disable=SC1091
source commons

log() { echo -e "$(date --iso-8601=seconds)" "$1"; }
error() { log "ERROR: $1"; }
warn() { log "WARNING: $1"; }
inf() { log "INFO: $1"; }

# takes the first argument as the version. Defaults to the latest version
# of monasca-ui if no argument is specified.
MONASCA_UI_VERSION=${1:-$(pip search monasca-ui | grep monasca-ui | \
                            awk '{print $2}' | sed 's|(||' | sed 's|)||')}
UPPER_CONSTRAINTS_FILE=${2:-""}

MONASCA_UI_TMP_DIR="${TMP_DIR}/monasca-ui"

mkdir -p "${MONASCA_UI_TMP_DIR}"

inf "Creating virtual environment in temporary location"
virtualenv "${MONASCA_UI_TMP_DIR}"

inf "Downloading monasca-ui in version: ${MONASCA_UI_VERSION}"
if [ -z "${UPPER_CONSTRAINTS_FILE}" ]; then
    inf "No upper constraints file specified"
    "${MONASCA_UI_TMP_DIR}"/bin/pip install monasca-ui=="$MONASCA_UI_VERSION"
else
    inf "Using upper constraints file: ${UPPER_CONSTRAINTS_FILE}"
    "${MONASCA_UI_TMP_DIR}"/bin/pip install -c "${UPPER_CONSTRAINTS_FILE}" \
      monasca-ui=="$MONASCA_UI_VERSION"
fi

LOCAL_SETTINGS_FILE=$(find "${MONASCA_UI_TMP_DIR}" -name local_settings.py)
sed -i -e "s/192.168.10.4:5601/<kibana_host>:5601/g" "${LOCAL_SETTINGS_FILE}"

virtualenv --relocatable "${MONASCA_UI_TMP_DIR}"

cp configure_monasca_ui.sh "${MONASCA_UI_TMP_DIR}"/bin

inf "Downloading latest Makeself"
if [ -d "${MAKESELF_DIR}" ]; then
    cd "${MAKESELF_DIR}" || exit
    git pull
    cd -
else
    git clone "${MAKESELF_REPO}" "${MAKESELF_DIR}"
fi

cat monasca_ui_help_header > monasca_ui_help_header.tmp

inf "Creating monasca-ui installer file"
"${MAKESELF_DIR}"/makeself.sh --notemp \
                              --tar-quietly \
                              --help-header monasca_ui_help_header.tmp \
                              "${MONASCA_UI_TMP_DIR}" \
                              monasca-ui-"${MONASCA_UI_VERSION}".run \
                              "Monasca UI installer" \
                              ./bin/configure_monasca_ui.sh

inf "Removing temporary files"
rm -rf "${MONASCA_UI_TMP_DIR}"

inf "Process of creating monasca-ui installer ended successfully"
