#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  sudo --preserve-env=EDGE_DASHBOARD_HOSTNAME,EDGE_API_HOSTNAME,EDGE_AUTH_HOSTNAME,EDGE_DASHBOARD_BASIC_AUTH_USERNAME,EDGE_DASHBOARD_BASIC_AUTH_PASSWORD_HASH ./scripts/sync_edge_config.sh
  ./scripts/sync_edge_config.sh --render <path>

Required environment:
  EDGE_DASHBOARD_HOSTNAME
  EDGE_API_HOSTNAME
  EDGE_AUTH_HOSTNAME
  EDGE_DASHBOARD_BASIC_AUTH_USERNAME
  EDGE_DASHBOARD_BASIC_AUTH_PASSWORD_HASH

Optional environment:
  EDGE_DASHBOARD_UPSTREAM_PORT  default: 8080
  EDGE_API_UPSTREAM_PORT        default: 3000
  EDGE_AUTH_UPSTREAM_PORT       default: 9000
  EDGE_CONTAINER_NAME           default: craftalism-edge
  EDGE_CADDYFILE_PATH           default: /opt/craftalism/edge/Caddyfile
  EDGE_COMPOSE_PATH             default: /opt/craftalism/edge/docker-compose.yml
EOF
}

render_path=""
if [[ "${1:-}" == "--render" ]]; then
  if [[ $# -ne 2 ]]; then
    usage >&2
    exit 2
  fi
  render_path="$2"
elif [[ $# -ne 0 ]]; then
  usage >&2
  exit 2
fi

required_variables=(
  EDGE_DASHBOARD_HOSTNAME
  EDGE_API_HOSTNAME
  EDGE_AUTH_HOSTNAME
  EDGE_DASHBOARD_BASIC_AUTH_USERNAME
  EDGE_DASHBOARD_BASIC_AUTH_PASSWORD_HASH
)

for variable_name in "${required_variables[@]}"; do
  if [[ -z "${!variable_name:-}" ]]; then
    echo "${variable_name} must be set" >&2
    exit 1
  fi
done

dashboard_upstream_port="${EDGE_DASHBOARD_UPSTREAM_PORT:-8080}"
api_upstream_port="${EDGE_API_UPSTREAM_PORT:-3000}"
auth_upstream_port="${EDGE_AUTH_UPSTREAM_PORT:-9000}"
edge_container_name="${EDGE_CONTAINER_NAME:-craftalism-edge}"
caddyfile_path="${EDGE_CADDYFILE_PATH:-/opt/craftalism/edge/Caddyfile}"
compose_path="${EDGE_COMPOSE_PATH:-/opt/craftalism/edge/docker-compose.yml}"

for port in "${dashboard_upstream_port}" "${api_upstream_port}" "${auth_upstream_port}"; do
  if [[ ! "${port}" =~ ^[0-9]+$ ]] || ((port < 1 || port > 65535)); then
    echo "Upstream ports must be integers between 1 and 65535" >&2
    exit 1
  fi
done

write_config() {
  local destination="$1"

  umask 077
  cat >"${destination}" <<EOF
http://${EDGE_DASHBOARD_HOSTNAME}, http://${EDGE_API_HOSTNAME}, http://${EDGE_AUTH_HOSTNAME} {
  redir https://{host}{uri} permanent
}

${EDGE_DASHBOARD_HOSTNAME} {
  encode zstd gzip
  basic_auth {
    ${EDGE_DASHBOARD_BASIC_AUTH_USERNAME} ${EDGE_DASHBOARD_BASIC_AUTH_PASSWORD_HASH}
  }
  reverse_proxy 127.0.0.1:${dashboard_upstream_port}
}

${EDGE_API_HOSTNAME} {
  encode zstd gzip
  reverse_proxy 127.0.0.1:${api_upstream_port}
}

${EDGE_AUTH_HOSTNAME} {
  encode zstd gzip
  reverse_proxy 127.0.0.1:${auth_upstream_port}
}
EOF
}

if [[ -n "${render_path}" ]]; then
  write_config "${render_path}"
  exit 0
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run the edge sync as root so it can update ${caddyfile_path}" >&2
  exit 1
fi

for command_name in docker curl install; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Required command not found: ${command_name}" >&2
    exit 1
  fi
done

if [[ ! -f "${compose_path}" ]]; then
  echo "Infra-owned edge compose file not found: ${compose_path}" >&2
  exit 1
fi

candidate="$(mktemp)"
backup="${caddyfile_path}.bak"
trap 'rm -f "${candidate}"' EXIT
write_config "${candidate}"

docker cp "${candidate}" "${edge_container_name}:/tmp/Caddyfile.candidate"
docker exec "${edge_container_name}" caddy validate --config /tmp/Caddyfile.candidate --adapter caddyfile

if [[ -f "${caddyfile_path}" ]]; then
  install -m 0600 -o root -g root "${caddyfile_path}" "${backup}"
fi
install -m 0644 -o root -g root "${candidate}" "${caddyfile_path}"

displaced_container="${edge_container_name}-displaced-$(date +%s)"
docker stop "${edge_container_name}"
docker rename "${edge_container_name}" "${displaced_container}"

rollback_edge() {
  docker rm -f "${edge_container_name}" >/dev/null 2>&1 || true
  if [[ -f "${backup}" ]]; then
    install -m 0644 -o root -g root "${backup}" "${caddyfile_path}"
  fi
  docker rename "${displaced_container}" "${edge_container_name}"
  docker start "${edge_container_name}"
}

if ! docker compose -f "${compose_path}" up -d --force-recreate; then
  rollback_edge
  echo "Infra-owned edge recreation failed; the previous configuration was restored when available" >&2
  exit 1
fi

response_headers="$(mktemp)"
trap 'rm -f "${candidate}" "${response_headers}"' EXIT
status_code=""
for _ in {1..15}; do
  if status_code="$(
    curl --silent --show-error \
      --dump-header "${response_headers}" \
      --output /dev/null \
      --write-out '%{http_code}' \
      "https://${EDGE_DASHBOARD_HOSTNAME}/"
  )"; then
    break
  fi
  sleep 1
done

if [[ "${status_code}" != "401" ]] || ! grep -qi '^www-authenticate:' "${response_headers}"; then
  rollback_edge
  echo "Dashboard auth verification failed: expected HTTP 401 with WWW-Authenticate, got HTTP ${status_code}" >&2
  exit 1
fi

docker rm "${displaced_container}" >/dev/null
echo "Infra-owned edge configuration synced; unauthenticated dashboard access returns HTTP 401."
