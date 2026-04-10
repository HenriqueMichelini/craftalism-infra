#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
main_tf="${repo_root}/main.tf"

if [[ ! -f "${main_tf}" ]]; then
  echo "main.tf not found at ${main_tf}" >&2
  exit 1
fi

python3 - "${main_tf}" <<'PY'
import pathlib
import re
import sys


def collect_named_blocks(text: str, header_pattern: str) -> list[str]:
    blocks: list[str] = []
    pattern = re.compile(header_pattern, re.M)
    search_start = 0

    while True:
        match = pattern.search(text, search_start)
        if not match:
            return blocks

        brace_start = text.find("{", match.start())
        if brace_start == -1:
            raise SystemExit(f"Block header matched without opening brace: {header_pattern}")

        depth = 0
        for index in range(brace_start, len(text)):
            char = text[index]
            if char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    blocks.append(text[brace_start + 1:index])
                    search_start = index + 1
                    break
        else:
            raise SystemExit(f"Unclosed block for pattern: {header_pattern}")


main_tf = pathlib.Path(sys.argv[1]).read_text()

security_group_blocks = collect_named_blocks(
    main_tf,
    r'^\s*resource\s+"aws_security_group"\s+"craftalism"\s*{',
)
if len(security_group_blocks) != 1:
    print("Expected exactly one aws_security_group.craftalism resource", file=sys.stderr)
    sys.exit(1)

body = security_group_blocks[0]

approved_ports = {22, 80, 443, 25565}
seen_ports = set()

for block in collect_named_blocks(body, r'^\s*ingress\s*{'):
    from_match = re.search(r'from_port\s*=\s*(\d+)', block)
    to_match = re.search(r'to_port\s*=\s*(\d+)', block)
    cidr_match = re.search(r'cidr_blocks\s*=\s*(?P<cidrs>[^\n]+)', block)

    if not from_match or not to_match or not cidr_match:
        print("Ingress block is missing from_port, to_port, or cidr_blocks", file=sys.stderr)
        sys.exit(1)

    from_port = int(from_match.group(1))
    to_port = int(to_match.group(1))
    cidrs = cidr_match.group("cidrs")

    if from_port != to_port:
        print(f"Ingress block uses a port range {from_port}-{to_port}; only single approved ports are allowed", file=sys.stderr)
        sys.exit(1)

    if from_port not in approved_ports:
        print(f"Ingress block exposes unapproved port {from_port}", file=sys.stderr)
        sys.exit(1)

    if from_port == 22 and "var.ssh_allowed_cidrs" in cidrs:
        print("Static SSH ingress must not reference var.ssh_allowed_cidrs directly; keep SSH opt-in via the dynamic block", file=sys.stderr)
        sys.exit(1)

    seen_ports.add(from_port)

dynamic_blocks = collect_named_blocks(body, r'^\s*dynamic\s+"ingress"\s*{')
if len(dynamic_blocks) != 1:
    print("Expected exactly one dynamic SSH ingress block", file=sys.stderr)
    sys.exit(1)

dynamic_block = dynamic_blocks[0]
required_dynamic_snippets = [
    "for_each = var.ssh_allowed_cidrs",
    "from_port   = 22",
    "to_port     = 22",
    "cidr_blocks = [ingress.value]",
]

for snippet in required_dynamic_snippets:
    if snippet not in dynamic_block:
        print(f"Dynamic SSH ingress block is missing required snippet: {snippet}", file=sys.stderr)
        sys.exit(1)

required_static_ports = {80, 443, 25565}
missing_ports = required_static_ports - seen_ports
if missing_ports:
    ports = ", ".join(str(port) for port in sorted(missing_ports))
    print(f"Missing required static ingress ports: {ports}", file=sys.stderr)
    sys.exit(1)

print("Ingress policy check passed.")
PY
