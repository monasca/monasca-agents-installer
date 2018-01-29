#!/bin/bash -e

# shellcheck disable=SC1091
source commons

# takes the first argument as the version. Defaults to the latest version
# of monasca-agent if no argument is specified.
MONASCA_AGENT_VERSION=$(pip search monasca-agent | grep monasca-agent | \
                        awk '{print $2}' | sed 's|(||' | sed 's|)||')
UPPER_CONSTRAINTS_FILE=""
INSTALL_LIBVIRT_DEPENDENCIES=false

# check for additional arguments in call to override default values (above)
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        -v|--monasca_agent_version)
        MONASCA_AGENT_VERSION="$2"
        shift 2
        ;;
        -u|--upper_constraints_file)
        UPPER_CONSTRAINTS_FILE="$2"
        shift 2
        ;;
        --install_libvirt_dependencies)
        INSTALL_LIBVIRT_DEPENDENCIES=true
        shift
        ;;
        *)    # unknown option
        shift
        ;;
    esac
done

MONASCA_AGENT_TMP_DIR="${TMP_DIR}/monasca-agent"
PIP_DEPENDENCIES=("pymysql")
LIBVIRT_DEPENDENCIES=("libvirt-python" "lxml" "python-neutronclient" "python-novaclient")

mkdir -p "${MONASCA_AGENT_TMP_DIR}"

echo ">>> Creating virtual environment in temporary location"
virtualenv "${MONASCA_AGENT_TMP_DIR}"

echo ">>> Downloading Monasca Agent in version: ${MONASCA_AGENT_VERSION}"
if [ -z "${UPPER_CONSTRAINTS_FILE}" ]; then
    echo ">>> No upper constraints file specified"
    "${MONASCA_AGENT_TMP_DIR}"/bin/pip install monasca-agent=="$MONASCA_AGENT_VERSION"
    for pip_dependencies in "${PIP_DEPENDENCIES[@]}"; do
        "${MONASCA_AGENT_TMP_DIR}"/bin/pip install "$pip_dependencies"
    done
    if [ ${INSTALL_LIBVIRT_DEPENDENCIES} = true ]; then
        echo ">>> Downloading libvirt dependencies"
        for libvirt_dependencies in "${LIBVIRT_DEPENDENCIES[@]}"; do
            "${MONASCA_AGENT_TMP_DIR}"/bin/pip install "$libvirt_dependencies"
        done
    fi
else
    echo ">>> Using upper constraints file: ${UPPER_CONSTRAINTS_FILE}"
    "${MONASCA_AGENT_TMP_DIR}"/bin/pip install -c "${UPPER_CONSTRAINTS_FILE}" monasca-agent=="$MONASCA_AGENT_VERSION"
    for dependencies in "${PIP_DEPENDENCIES[@]}"; do
        "${MONASCA_AGENT_TMP_DIR}"/bin/pip install -c "${UPPER_CONSTRAINTS_FILE}" "$dependencies"
    done
    if [ ${INSTALL_LIBVIRT_DEPENDENCIES} = true ]; then
        echo ">>> Downloading libvirt dependencies"
        for libvirt_dependencies in "${LIBVIRT_DEPENDENCIES[@]}"; do
            "${MONASCA_AGENT_TMP_DIR}"/bin/pip install -c "${UPPER_CONSTRAINTS_FILE}" "$libvirt_dependencies"
        done
    fi
fi
virtualenv --relocatable "${MONASCA_AGENT_TMP_DIR}"

cp configure_metrics_agent.sh "${MONASCA_AGENT_TMP_DIR}"/bin

echo ">>> Downloading latest Makeself"
if [ -d "${MAKESELF_DIR}" ]; then
    cd "${MAKESELF_DIR}" || exit
    git pull
    cd -
else
    git clone "${MAKESELF_REPO}" "${MAKESELF_DIR}"
fi

cat metrics_agent_help_header > metrics_agent_help_header.tmp
"${MONASCA_AGENT_TMP_DIR}"/bin/python "${MONASCA_AGENT_TMP_DIR}"/bin/monasca-setup --help \
    >> metrics_agent_help_header.tmp

echo ">>> Creating Monasca Agent installer file"
"${MAKESELF_DIR}"/makeself.sh --notemp \
                              --tar-quietly \
                              --help-header metrics_agent_help_header.tmp \
                              "${MONASCA_AGENT_TMP_DIR}" \
                              monasca-agent-"${MONASCA_AGENT_VERSION}".run \
                              "Monasca Agent installer" \
                              ./bin/configure_metrics_agent.sh

echo ">>> Removing temporary files"
rm -rf "${MONASCA_AGENT_TMP_DIR}"

echo ">>> Process of creating Monasca Agent installer ended successfully"
