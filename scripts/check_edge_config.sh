#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rendered_config="$(mktemp)"
trap 'rm -f "${rendered_config}"' EXIT

EDGE_DASHBOARD_HOSTNAME="dashboard.example.com" \
EDGE_API_HOSTNAME="api.example.com" \
EDGE_AUTH_HOSTNAME="auth.example.com" \
EDGE_DASHBOARD_BASIC_AUTH_USERNAME="operator" \
EDGE_DASHBOARD_BASIC_AUTH_PASSWORD_HASH='$2a$14$01234567890123456789012345678901234567890123456789012' \
  "${repo_root}/scripts/sync_edge_config.sh" --render "${rendered_config}"

python3 - "${repo_root}/templates/cloud-init.yaml.tftpl" "${rendered_config}" <<'PY'
import pathlib
import re
import sys

bootstrap = pathlib.Path(sys.argv[1]).read_text()
rendered = pathlib.Path(sys.argv[2]).read_text()

checks = [
    (
        bootstrap,
        r"\$\{dashboard_hostname\}\s*\{(?P<body>.*?)\n\s*\$\{api_hostname\}\s*\{",
        "bootstrap dashboard route",
    ),
    (
        rendered,
        r"dashboard\.example\.com\s*\{(?P<body>.*?)\napi\.example\.com\s*\{",
        "rendered dashboard route",
    ),
]

for text, pattern, label in checks:
    match = re.search(pattern, text, re.S)
    if not match:
        raise SystemExit(f"Could not find {label}")

    body = match.group("body")
    auth_match = re.search(r"\bbasic_?auth\s*\{", body)
    proxy_match = re.search(r"\breverse_proxy\s+127\.0\.0\.1:(?:\$\{dashboard_upstream_port\}|8080)", body)
    if not auth_match:
        raise SystemExit(f"{label} does not enforce basic auth")
    if not proxy_match:
        raise SystemExit(f"{label} does not proxy to the dashboard loopback upstream")
    if auth_match.start() > proxy_match.start():
        raise SystemExit(f"{label} must apply basic auth before the dashboard reverse proxy")

print("Edge configuration policy check passed.")
PY
