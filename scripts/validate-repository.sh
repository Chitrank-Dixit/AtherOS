#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

required=(README.md ROADMAP.md CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md LICENSE AGENTS.md Makefile \
  docs/product/vision.md docs/architecture/overview.md docs/architecture/security-model.md \
  docs/research/sprint-0-report.md docs/adr/ADR-001-base-distribution.md schemas/experiment-record.schema.json \
  experiments/arch/README.md experiments/nixos/README.md scripts/validate-environment.sh \
  experiments/nixos/scripts/build-iso.sh)
failed=0
for path in "${required[@]}"; do
  if [[ -f "$path" ]]; then printf 'OK %s\n' "$path"; else printf 'MISSING %s\n' "$path" >&2; failed=1; fi
done
if (( failed )); then echo 'Repository structure validation failed.' >&2; exit 1; fi

while IFS= read -r -d '' script; do bash -n "$script"; done < <(find scripts experiments -type f -name '*.sh' -print0)
echo 'Shell syntax: passed.'
if command -v python3 >/dev/null 2>&1; then
  python3 -m py_compile scripts/generate-report.py
  python3 -m json.tool schemas/experiment-record.schema.json >/dev/null
  echo 'Python and JSON syntax: passed.'
else
  echo 'Python and JSON syntax: skipped (python3 unavailable).'
fi
echo 'Repository validation passed for available checks.'
