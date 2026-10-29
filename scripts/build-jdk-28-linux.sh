#!/usr/bin/env bash
set -euo pipefail

readonly tag="jdk-28+13"
readonly expected_commit="fd9698357bb034c527c9ccdd6888a2abd75c0043"
readonly expected_boot_jdk_sha256="83c78367f8c81257beef72aca4bbbf8e6dac8ca2b3a4546a85879a09e6e4e128"
readonly expected_jtreg_commit="551e17adac0579859012c4c46318b8fa3cf2ff37"
readonly source_name="openjdk-jdk-28-13"
readonly conf_name="mikohime-release"

readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly repo_root="$(cd "$script_dir/.." && pwd)"
readonly patch_file="$repo_root/patches/jdk-28+13-allow-unverified-agent-classes.patch"
readonly work_dir="${WORK_DIR:-$HOME/.cache/mikohime-jdk}"
readonly source_dir="$work_dir/$source_name"
readonly dist_dir="${DIST_DIR:-$repo_root/dist}"

: "${BOOT_JDK:?Set BOOT_JDK to an OpenJDK 26 boot JDK}"
: "${BOOT_JDK_ARCHIVE:?Set BOOT_JDK_ARCHIVE to the verified OpenJDK 26+35 archive}"
: "${JTREG_HOME:?Set JTREG_HOME to jtreg 8.3+1}"

for executable in "$BOOT_JDK/bin/java" "$JTREG_HOME/bin/jtreg"; do
  if [[ ! -x "$executable" ]]; then
    echo "Required executable not found: $executable" >&2
    exit 1
  fi
done

echo "$expected_boot_jdk_sha256  $BOOT_JDK_ARCHIVE" | sha256sum -c -
grep -qx 'JAVA_RUNTIME_VERSION="26+35-2893"' "$BOOT_JDK/release"
grep -qx 'OS_ARCH="x86_64"' "$BOOT_JDK/release"
grep -qx 'OS_NAME="Linux"' "$BOOT_JDK/release"

readonly jtreg_source="${JTREG_SOURCE:-$(cd "$JTREG_HOME/../../.." && pwd)}"
if [[ "$(git -C "$jtreg_source" rev-parse HEAD)" != "$expected_jtreg_commit" ]] ||
   [[ "$(git -C "$jtreg_source" describe --tags --exact-match HEAD)" != "jtreg-8.3+1" ]]; then
  echo "JTREG_HOME must refer to a build of jtreg-8.3+1." >&2
  exit 1
fi

if [[ "$(uname -m)" != "x86_64" ]] ||
   ! grep -q '^VERSION_ID="24.04"$' /etc/os-release ||
   [[ "$(gcc -dumpversion | cut -d. -f1)" != "13" ]]; then
  echo "This release must be built on Ubuntu 24.04 x64 with GCC 13." >&2
  exit 1
fi

mkdir -p "$work_dir" "$dist_dir"

if [[ ! -d "$source_dir/.git" ]]; then
  git clone --depth 1 --branch "$tag" \
    https://github.com/openjdk/jdk.git "$source_dir"
fi

actual_commit="$(git -C "$source_dir" rev-parse HEAD)"
if [[ "$actual_commit" != "$expected_commit" ]]; then
  echo "Unexpected source commit: $actual_commit" >&2
  exit 1
fi

if ! git -C "$source_dir" diff --cached --quiet; then
  echo "Source tree contains staged changes." >&2
  exit 1
fi

unexpected_untracked="$(
  git -C "$source_dir" ls-files --others --exclude-standard |
    grep -Ev '^(config\.log|configure\.log)$' || true
)"
if [[ -n "$unexpected_untracked" ]]; then
  echo "Source tree contains unexpected untracked files." >&2
  echo "$unexpected_untracked" >&2
  exit 1
fi

if git -C "$source_dir" diff --quiet; then
  git -C "$source_dir" apply --check "$patch_file"
  git -C "$source_dir" apply "$patch_file"
elif git -C "$source_dir" apply --reverse --check "$patch_file"; then
  git -C "$source_dir" apply --reverse "$patch_file"
  if ! git -C "$source_dir" diff --quiet; then
    git -C "$source_dir" apply "$patch_file"
    echo "Source tree contains changes outside the expected patch." >&2
    exit 1
  fi
  git -C "$source_dir" apply "$patch_file"
else
  echo "Source tree contains incompatible changes." >&2
  exit 1
fi

readonly source_epoch="$(git -C "$source_dir" show -s --format=%ct HEAD)"
export SOURCE_DATE_EPOCH="$source_epoch"

(
  cd "$source_dir"
  bash configure \
    --build=x86_64-unknown-linux-gnu \
    --openjdk-target=x86_64-unknown-linux-gnu \
    --with-conf-name="$conf_name" \
    --with-boot-jdk="$BOOT_JDK" \
    --with-jtreg="$JTREG_HOME" \
    --with-debug-level=release \
    --with-native-debug-symbols=none \
    --with-source-date="$source_epoch" \
    --with-version-pre="ea" \
    --with-version-build="13" \
    --with-vendor-name="Mikohime Unofficial JVM" \
    --with-vendor-version-string="agent-verification-policy" \
    --with-version-opt="mikohime-agent-verification"

  make CONF="$conf_name" images
  make CONF="$conf_name" test \
    TEST="test/hotspot/jtreg/runtime/verifier/CFLH/TestVerify.java"

  jdk="build/$conf_name/images/jdk"
  "$jdk/bin/java" \
    -XX:+UnlockDiagnosticVMOptions \
    -XX:+AllowUnverifiedAgentClasses \
    -version
  if "$jdk/bin/java" -XX:+AllowUnverifiedAgentClasses -version \
      > build/"$conf_name"/locked-option.log 2>&1; then
    echo "Diagnostic option was accepted without unlocking." >&2
    exit 1
  fi
  test -s "$jdk/LICENSE"
  test -d "$jdk/legal"
)

readonly image_dir="$source_dir/build/$conf_name/images"
readonly package_name="jdk-28+13Miko"
readonly archive="$dist_dir/$package_name.tar.gz"

tar -C "$image_dir" \
  --sort=name \
  --mtime="@$source_epoch" \
  --owner=0 \
  --group=0 \
  --numeric-owner \
  --transform="s,^jdk,$package_name," \
  -cf - jdk |
  gzip -n > "$archive"

(
  cd "$dist_dir"
  sha256sum "$(basename "$archive")" > "$(basename "$archive").sha256"
)

bash "$repo_root/scripts/package-source.sh" \
  "$source_dir" "$work_dir" "$dist_dir" "$source_epoch" "$archive" \
  build-jdk-28-linux.sh
echo "Created $archive"
