#!/usr/bin/env bash
# Create a new output directory only when no existing path component is a symlink.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 OUTPUT_DIRECTORY" >&2
  exit 2
fi

if ! output_path=$(realpath -m -s -- "$1"); then
  echo "ERROR: cannot normalize output path: $1" >&2
  exit 1
fi
if [[ $output_path == *$'\n'* ]]; then
  echo 'ERROR: output path cannot contain newline characters.' >&2
  exit 1
fi

reject_symlink_components() {
  local current=''
  local component
  local -a components
  IFS='/' read -r -a components <<< "$output_path"
  for component in "${components[@]}"; do
    [[ -z $component ]] && continue
    current+="/$component"
    if [[ -L $current ]]; then
      echo "ERROR: refusing symlink component in output path: $current" >&2
      return 1
    fi
  done
}

reject_symlink_components || exit 1

if [[ -e $output_path || -L $output_path ]]; then
  echo "ERROR: refusing to reuse existing output path: $output_path" >&2
  exit 1
fi
parent_path=$(dirname -- "$output_path")
if ! mkdir -p -- "$parent_path"; then
  echo "ERROR: cannot create output parent directory: $parent_path" >&2
  exit 1
fi
reject_symlink_components || exit 1
if [[ -e $output_path || -L $output_path ]] || ! mkdir -- "$output_path"; then
  echo "ERROR: output path exists or appeared during creation: $output_path" >&2
  exit 1
fi
printf '%s\n' "$output_path"
