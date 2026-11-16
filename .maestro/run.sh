#!/bin/sh
set -eu

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  printf 'Usage: sh .maestro/run.sh <device-serial>\n' >&2
  exit 2
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$script_dir/.."
mkdir -p build/maestro

exec maestro --device "$1" test --format JUNIT \
  --output build/maestro/report.xml .maestro/
