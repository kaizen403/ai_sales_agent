#!/usr/bin/env bash
# Build firmware (if needed) and run Robot Framework tests via renode-test.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="${HOME}/.local/bin:/usr/local/bin:/opt/renode:${PATH}"

if ! command -v renode >/dev/null 2>&1 || ! command -v renode-test >/dev/null 2>&1; then
  echo "Renode not found. Run: ${ROOT}/scripts/install_deps.sh" >&2
  exit 1
fi
if ! command -v robot >/dev/null 2>&1; then
  echo "Robot Framework not found. Run: ${ROOT}/scripts/install_deps.sh" >&2
  exit 1
fi
if ! command -v arm-none-eabi-gcc >/dev/null 2>&1; then
  echo "arm-none-eabi-gcc not found. Run: ${ROOT}/scripts/install_deps.sh" >&2
  exit 1
fi

echo "==> Building firmware..."
make -C "${ROOT}/firmware" -j"$(nproc)"

RESULTS="${ROOT}/tests/results"
mkdir -p "${RESULTS}"

echo "==> Running Robot tests..."
cd "${ROOT}"
renode-test \
  -r "${RESULTS}" \
  "${ROOT}/tests/sample_mcu.robot"

echo "==> Results under ${RESULTS}"
