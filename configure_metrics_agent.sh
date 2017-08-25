#!/bin/bash

echo "Configuring agent..."
BIN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

${BIN_DIR}/python ${BIN_DIR}/monasca-setup $@