#!/usr/bin/env bash
set -euo pipefail

readonly tag="jdk-28+13"
readonly expected_commit="fd9698357bb034c527c9ccdd6888a2abd75c0043"
readonly expected_boot_jdk_sha256="2dd2d92c9374cd49a120fe9d916732840bf6bb9f0e0cc29794917a3c08b99c5f"
readonly expected_jtreg_commit="551e17adac0579859012c4c46318b8fa3cf2ff37"
readonly source_name="openjdk-jdk-28-13-windows"
readonly conf_name="mikohime-windows-release"

readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly repo_root="$(cd "$script_dir/.." && pwd)"
readonly patch_file="$repo_root/patches/jdk-28+13-allow-unverified-agent-classes.patch"
readonly work_dir="${WORK_DIR:-/c/miko-jdk-build}"
readonly source_dir="$work_dir/$source_name"
readonly dist_dir="${DIST_DIR:-$repo_root/dist}"

# Do not inherit Git-for-Windows internals into the MSYS2 Git installation.
unset GIT_EXEC_PATH GIT_TEMPLATE_DIR

: "${BOOT_JDK:?Set BOOT_JDK to an OpenJDK 26 Windows x64 boot JDK}"
: "${BOOT_JDK_ARCHIVE:?Set BOOT_JDK_ARCHIVE to the verified OpenJDK 26+35 Windows archive}"
: "${JTREG_HOME:?Set JTREG_HOME to jtreg 8.3+1}"

if [[ "$(uname -s)" != MSYS_NT-* ]]; then
  echo "This release must be built from an MSYS2 MSYS shell on Windows x64." >&2
  exit 1
fi

for executable in \
  "$BOOT_JDK/bin/java.exe" \
  "$JTREG_HOME/bin/jtreg" \
  /c/Program\ Files\ \(x86\)/Microsoft\ Visual\ Studio/Installer/vswhere.exe; do
  if [[ ! -x "$executable" ]]; then
    echo "Required executable not found: $executable" >&2
    exit 1
  fi
done

echo "$expected_boot_jdk_sha256  $BOOT_JDK_ARCHIVE" | sha256sum -c -
grep -qx 'JAVA_RUNTIME_VERSION="26+35-2893"' "$BOOT_JDK/release"
grep -qx 'OS_ARCH="x86_64"' "$BOOT_JDK/release"
grep -qx 'OS_NAME="Windows"' "$BOOT_JDK/release"

readonly jtreg_source="${JTREG_SOURCE:-$(cd "$JTREG_HOME/../../.." && pwd)}"
if [[ "$(git -C "$jtreg_source" rev-parse HEAD)" != "$expected_jtreg_commit" ]] ||
   [[ "$(git -C "$jtreg_source" describe --tags --exact-match HEAD)" != "jtreg-8.3+1" ]]; then
  echo "JTREG_HOME must refer to a build of jtreg-8.3+1." >&2
  exit 1
fi

readonly vswhere="/c/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe"
readonly vs_path="$(
  "$vswhere" -latest -products "*" \
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 \
    -property installationPath
)"
if [[ -z "$vs_path" ]]; then
  echo "Visual Studio 2022 C++ Build Tools were not found." >&2
  exit 1
fi

for executable in autoconf make tar zip unzip git; do
  if ! command -v "$executable" >/dev/null; then
    echo "Required MSYS2 command not found: $executable" >&2
    exit 1
  fi
done

mkdir -p "$work_dir" "$dist_dir"

if [[ ! -d "$source_dir/.git" ]]; then
  git -c core.autocrlf=false clone --depth 1 --branch "$tag" \
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
    --with-conf-name="$conf_name" \
    --with-boot-jdk="$BOOT_JDK" \
    --with-jtreg="$JTREG_HOME" \
    --with-toolchain-version=2022 \
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
  "$jdk/bin/java.exe" \
    -XX:+UnlockDiagnosticVMOptions \
    -XX:+AllowUnverifiedAgentClasses \
    -version
  if "$jdk/bin/java.exe" -XX:+AllowUnverifiedAgentClasses -version \
      > build/"$conf_name"/locked-option.log 2>&1; then
    echo "Diagnostic option was accepted without unlocking." >&2
    exit 1
  fi
  test -s "$jdk/legal/java.base/LICENSE"
  test -d "$jdk/legal"
)

readonly image_dir="$source_dir/build/$conf_name/images"
readonly package_name="jdk-28+13Miko"
readonly staging_dir="$work_dir/package/$package_name"
readonly archive="$dist_dir/$package_name-windows-x64.zip"

rm -rf "$work_dir/package"
mkdir -p "$(dirname "$staging_dir")"
cp -a "$image_dir/jdk" "$staging_dir"
find "$staging_dir" -exec touch --date="@$source_epoch" {} +
rm -f "$archive"
(
  cd "$work_dir/package"
  zip -X -q -r "$archive" "$package_name"
)

(
  cd "$dist_dir"
  sha256sum "$(basename "$archive")" > "$(basename "$archive").sha256"
)

bash "$repo_root/scripts/package-source.sh" \
  "$source_dir" "$work_dir" "$dist_dir" "$source_epoch" "$archive" \
  build-jdk-28-windows.sh
echo "Created $archive"
