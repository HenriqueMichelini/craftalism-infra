#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
main_tf="${repo_root}/main.tf"
plan_path="${1:-}"

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
instance_blocks = collect_named_blocks(
    main_tf,
    r'^\s*resource\s+"aws_instance"\s+"craftalism"\s*{',
)
if len(instance_blocks) != 1:
    print("Expected exactly one aws_instance.craftalism resource", file=sys.stderr)
    sys.exit(1)

instance = instance_blocks[0]
lifecycle_blocks = collect_named_blocks(instance, r'^\s*lifecycle\s*{')
if not lifecycle_blocks or not any(re.search(r'\bprevent_destroy\s*=\s*true\b', block) for block in lifecycle_blocks):
    print("aws_instance.craftalism must keep lifecycle.prevent_destroy = true", file=sys.stderr)
    sys.exit(1)

if re.search(r'\buser_data_replace_on_change\s*=\s*true\b', instance):
    print("aws_instance.craftalism must not set user_data_replace_on_change = true", file=sys.stderr)
    sys.exit(1)

if not re.search(r'\bdisable_api_termination\s*=\s*true\b', instance):
    print("aws_instance.craftalism must enable disable_api_termination = true", file=sys.stderr)
    sys.exit(1)

root_blocks = collect_named_blocks(instance, r'^\s*root_block_device\s*{')
if not root_blocks or not any(re.search(r'\bdelete_on_termination\s*=\s*false\b', block) for block in root_blocks):
    print("aws_instance.craftalism root_block_device must set delete_on_termination = false", file=sys.stderr)
    sys.exit(1)

print("Instance safety configuration check passed.")
PY

if [[ -n "${plan_path}" ]]; then
  if [[ ! -f "${plan_path}" ]]; then
    echo "Terraform plan not found at ${plan_path}" >&2
    exit 1
  fi

  plan_json="$(mktemp)"
  trap 'rm -f "${plan_json}"' EXIT
  terraform show -json "${plan_path}" >"${plan_json}"

  python3 - "${plan_json}" <<'PY'
import json
import pathlib
import sys

plan = json.loads(pathlib.Path(sys.argv[1]).read_text())
unsafe_actions = {"delete", "delete_before_replace", "create_before_destroy"}

for change in plan.get("resource_changes", []):
    if change.get("address") != "aws_instance.craftalism":
        continue

    actions = change.get("change", {}).get("actions", [])
    if any(action in unsafe_actions for action in actions):
        print(
            f"Plan contains unsafe aws_instance.craftalism action(s): {', '.join(actions)}",
            file=sys.stderr,
        )
        sys.exit(1)

print("Terraform plan safety check passed.")
PY
fi
