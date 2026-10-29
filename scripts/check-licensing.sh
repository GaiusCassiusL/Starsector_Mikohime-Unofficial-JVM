#!/usr/bin/env bash
set -euo pipefail

readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly repo_root="$(cd "$script_dir/.." && pwd)"

for required_file in \
  LICENSE \
  THIRD_PARTY_NOTICES.md \
  SOURCE-DISTRIBUTION.md \
  patches/jdk-28+13-allow-unverified-agent-classes.patch; do
  if [[ ! -s "$repo_root/$required_file" ]]; then
    echo "Required licensing/source file is missing or empty: $required_file" >&2
    exit 1
  fi
done

grep -q 'does not relicense OpenJDK' "$repo_root/LICENSE"
grep -q 'MIT license does not replace' "$repo_root/SOURCE-DISTRIBUTION.md"
grep -q 'Classpath Exception' "$repo_root/THIRD_PARTY_NOTICES.md"
grep -q 'jdk-28+13Miko-source.tar.gz' "$repo_root/SOURCE-DISTRIBUTION.md"

bash -n "$repo_root/scripts/build-jdk-28-linux.sh"
bash -n "$repo_root/scripts/build-jdk-28-windows.sh"
bash -n "$repo_root/scripts/package-source.sh"
grep -q 'Modified by Mikohime Unofficial JVM, 2026' \
  "$repo_root/patches/jdk-28+13-allow-unverified-agent-classes.patch"

echo "Licensing and source-distribution checks passed."
