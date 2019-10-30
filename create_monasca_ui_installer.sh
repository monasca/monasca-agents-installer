#!/bin/bash -e

# shellcheck disable=SC1091
source commons

log() { echo -e "$(date --iso-8601=seconds)" "$1"; }
error() { log "ERROR: $1"; }
warn() { log "WARNING: $1"; }
inf() { log "INFO: $1"; }

# takes the first argument as the version. Defaults to the latest version
# of monasca-ui if no argument is specified.
MONASCA_UI_VERSION=$(pip search monasca-ui | grep monasca-ui | \
                     awk '{print $2}' | sed 's|(||' | sed 's|)||')
UPPER_CONSTRAINTS_FILE=""
MONASCA_UI_FROM_GIT=false
MONASCA_UI_REPO="git+https://git.openstack.org/openstack/monasca-ui.git"

MONASCA_UI_TMP_DIR="${TMP_DIR}/monasca-ui"

# check for additional arguments in call to override default values (above)
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        -v|--monasca_ui_version)
        MONASCA_UI_VERSION="$2"
        shift 2
        ;;
        -u|--upper_constraints_file)
        UPPER_CONSTRAINTS_FILE="$2"
        shift 2
        ;;
        -r|--monasca_ui_repo)
        MONASCA_UI_REPO="$2"
        shift 2
        ;;
        *)    # unknown option
        shift
        ;;
    esac
done

mkdir -p "${MONASCA_UI_TMP_DIR}"

inf "Creating virtual environment in temporary location"
virtualenv "${MONASCA_UI_TMP_DIR}"

case ${MONASCA_UI_VERSION} in
    [0-9].[0-9].[0-9])
        MONASCA_UI_FROM_GIT=false
        ;;
    *) # Non proper version number found
        inf "Non SEMVER version provided, creating installer from Git"
        MONASCA_UI_FROM_GIT=true
        ;;
esac

inf "Downloading monasca-ui in version: ${MONASCA_UI_VERSION}"
if [ -z "${UPPER_CONSTRAINTS_FILE}" ]; then
    inf "No upper constraints file specified"

    if [ ${MONASCA_UI_FROM_GIT} = true ]; then
        "${MONASCA_UI_TMP_DIR}"/bin/pip install \
          "${MONASCA_UI_REPO}@${MONASCA_UI_VERSION}"
    else
        "${MONASCA_UI_TMP_DIR}"/bin/pip install monasca-ui=="$MONASCA_UI_VERSION"
    fi
else
    inf "Using upper constraints file: ${UPPER_CONSTRAINTS_FILE}"

    if [ ${MONASCA_UI_FROM_GIT} = true ]; then
        "${MONASCA_UI_TMP_DIR}"/bin/pip install -c "${UPPER_CONSTRAINTS_FILE}" \
          "${MONASCA_UI_REPO}@${MONASCA_UI_VERSION}"
    else
        "${MONASCA_UI_TMP_DIR}"/bin/pip install -c "${UPPER_CONSTRAINTS_FILE}" \
          monasca-ui=="$MONASCA_UI_VERSION"
    fi
fi

LOCAL_SETTINGS_FILE=$(find "${MONASCA_UI_TMP_DIR}" -name local_settings.py)
sed -i -e "s/192.168.10.4:5601/<kibana_host>:5601/g" "${LOCAL_SETTINGS_FILE}"

# Change name of the configuration file so it's not overwritten by default.
# Then when installation script is run with `--overwrite_conf` we will
# replace previous config file with this example file.
mv "${LOCAL_SETTINGS_FILE}" "${LOCAL_SETTINGS_FILE}.example"

# Clean Python binary files
find "${MONASCA_UI_TMP_DIR}" -name '*.pyc' -delete

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

# Fix for using e.g. `stable/pike` as version.
UI_SECURE_FILENAME=$(echo "monasca-ui-${MONASCA_UI_VERSION}" | \
                     sed -e 's/[^A-Za-z0-9._-]/-/g')

inf "Creating monasca-ui installer file"
"${MAKESELF_DIR}"/makeself.sh --notemp \
                              --tar-quietly \
                              --help-header monasca_ui_help_header.tmp \
                              "${MONASCA_UI_TMP_DIR}" \
                              "${UI_SECURE_FILENAME}".run \
                              "Monasca UI installer" \
                              ./bin/configure_monasca_ui.sh

inf "Removing temporary files"
rm -rf "${MONASCA_UI_TMP_DIR}"

inf "Process of creating monasca-ui installer ended successfully"
