#!/usr/bin/env bash
# generate_config.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
TPL_FILE="${SCRIPT_DIR}/config.tpl.json"
OUT_FILE="${SCRIPT_DIR}/config/config.json"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "❌  Missing .env file at ${ENV_FILE}"
  exit 1
fi

# load all variables
set -o allexport
source "${ENV_FILE}"
set +o allexport

# require envsubst
if ! command -v envsubst &>/dev/null; then
  echo "❌  envsubst not found. Install gettext (apt/yum install gettext)."
  exit 1
fi

# generate
envsubst <"${TPL_FILE}" >"${OUT_FILE}"
echo "✅  Generated ${OUT_FILE}"

# also generate Snell v3 config from .env
SNELL_CONF_FILE="${SCRIPT_DIR}/snell.conf"
cat >"${SNELL_CONF_FILE}" <<EOF
[snell-server]
listen = 0.0.0.0:${SNELL_PORT}
psk = ${SNELL_PSK}
obfs = ${SNELL_OBFS}
obfs-host = ${SNELL_OBFS_HOST}
ipv6 = ${SNELL_IPV6}
tfo = ${SNELL_TFO}
reuse-port = ${SNELL_REUSE_PORT}
EOF
echo "✅  Generated ${SNELL_CONF_FILE}"
