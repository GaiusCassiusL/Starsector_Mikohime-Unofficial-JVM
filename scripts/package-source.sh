#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 6 ]]; then
  echo "Usage: $0 SOURCE_DIR WORK_DIR DIST_DIR SOURCE_EPOCH BINARY_ARCHIVE BUILD_SCRIPT" >&2
  exit 2
fi

readonly source_dir="$1"
readonly work_dir="$2"
readonly dist_dir="$3"
readonly source_epoch="$4"
readonly binary_archive="$5"
readonly expected_build_script="$6"
readonly repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly source_package_name="jdk-28+13Miko-source"
readonly source_stage="$work_dir/source-package/$source_package_name"
readonly source_archive="$dist_dir/$source_package_name.tar.gz"

rm -rf "$source_stage"
mkdir -p "$source_stage/openjdk" \
  "$source_stage/project/patches" \
  "$source_stage/project/scripts" \
  "$source_stage/project/.github/workflows"

tar -C "$source_dir" \
  --exclude=.git \
  --exclude=build \
  --exclude=config.log \
  --exclude=configure.log \
  -cf - . |
  tar -C "$source_stage/openjdk" -xf -

cp "$repo_root/LICENSE" \
  "$repo_root/PROJECT_TEMPLATE.md" \
  "$repo_root/README.md" \
  "$repo_root/SOURCE-DISTRIBUTION.md" \
  "$repo_root/THIRD_PARTY_NOTICES.md" \
  "$source_stage/project/"
cp "$repo_root/patches/jdk-28+13-allow-unverified-agent-classes.patch" \
  "$source_stage/project/patches/"
cp "$repo_root/scripts/"*.sh "$source_stage/project/scripts/"
cp "$repo_root/.github/workflows/build-custom-jdks.yml" \
  "$source_stage/project/.github/workflows/"

tar -C "$work_dir/source-package" \
  --sort=name \
  --mtime="@$source_epoch" \
  --owner=0 \
  --group=0 \
  --numeric-owner \
  -cf - "$source_package_name" |
  gzip -n > "$source_archive"

for required_path in \
  "$source_package_name/openjdk/LICENSE" \
  "$source_package_name/project/LICENSE" \
  "$source_package_name/project/THIRD_PARTY_NOTICES.md" \
  "$source_package_name/project/scripts/$expected_build_script"; do
  tar -tzf "$source_archive" | grep -Fx "$required_path" >/dev/null
done

(
  cd "$dist_dir"
  sha256sum "$(basename "$source_archive")" > "$(basename "$source_archive").sha256"
  sha256sum -c "$(basename "$source_archive").sha256"
  sha256sum -c "$(basename "$binary_archive").sha256"
)

echo "Created $source_archive"
