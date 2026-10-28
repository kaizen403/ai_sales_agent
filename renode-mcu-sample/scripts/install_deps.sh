#!/usr/bin/env bash
# Non-interactive install of Renode, Robot Framework deps, and ARM GCC toolchain.
# Suitable for CI / cloud agents on Debian/Ubuntu x86_64.
set -euo pipefail

RENODE_VERSION="${RENODE_VERSION:-1.15.2}"
RENODE_INSTALL_DIR="${RENODE_INSTALL_DIR:-/opt/renode}"
RENODE_URL="${RENODE_URL:-https://github.com/renode/renode/releases/download/v${RENODE_VERSION}/renode-${RENODE_VERSION}.linux-portable.tar.gz}"

export DEBIAN_FRONTEND=noninteractive

echo "==> Ensuring base packages (wget, python3, pip, ARM GCC)..."
if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update -qq
  sudo apt-get install -y -qq \
    wget curl ca-certificates \
    python3 python3-pip python3-dev python3-setuptools \
    gcc-arm-none-eabi binutils-arm-none-eabi libnewlib-arm-none-eabi
fi

echo "==> Checking Renode..."
if command -v renode >/dev/null 2>&1; then
  echo "    Found: $(command -v renode)"
  renode --version 2>&1 | head -3 || true
elif [[ -x "${RENODE_INSTALL_DIR}/renode" ]]; then
  echo "    Found at ${RENODE_INSTALL_DIR}/renode (not on PATH yet)"
else
  echo "    Installing Renode ${RENODE_VERSION} portable -> ${RENODE_INSTALL_DIR}"
  tmp="$(mktemp -d)"
  wget -q "${RENODE_URL}" -O "${tmp}/renode.tgz"
  sudo mkdir -p "${RENODE_INSTALL_DIR}"
  sudo tar xf "${tmp}/renode.tgz" -C "${RENODE_INSTALL_DIR}" --strip-components=1
  rm -rf "${tmp}"
fi

if [[ -x "${RENODE_INSTALL_DIR}/renode" ]]; then
  sudo ln -sfn "${RENODE_INSTALL_DIR}/renode" /usr/local/bin/renode
  sudo ln -sfn "${RENODE_INSTALL_DIR}/renode-test" /usr/local/bin/renode-test
fi

echo "==> Installing Robot Framework (Renode-pinned versions)..."
# Match /opt/renode/tests/requirements.txt core pins
python3 -m pip install --user \
  'robotframework==6.1' \
  'robotframework-retryfailed==0.2.0' \
  'psutil==5.9.3' \
  'pyyaml==6.0.1'

# Ensure user local bin is discoverable
export PATH="${HOME}/.local/bin:/usr/local/bin:${RENODE_INSTALL_DIR}:${PATH}"

echo "==> Versions:"
command -v renode
renode --version 2>&1 | head -2
command -v renode-test
command -v robot
robot --version
command -v arm-none-eabi-gcc
arm-none-eabi-gcc --version | head -1

echo "==> Done. Add to PATH if needed:"
echo "    export PATH=\"\${HOME}/.local/bin:/usr/local/bin:${RENODE_INSTALL_DIR}:\${PATH}\""
