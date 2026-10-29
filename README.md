# Starsector_Mikohime-Unofficial-JVM

Custom OpenJDK builds for Starsector.

Use [PROJECT_TEMPLATE.md](PROJECT_TEMPLATE.md) to define the requirements,
design, build process, validation, and release criteria for each custom JDK.

## Current target

- OpenJDK `jdk-28+13`
- Commit `fd9698357bb034c527c9ccdd6888a2abd75c0043`
- Ubuntu 24.04 LTS, Linux x64
- Windows x64

The JDK adds this default-off diagnostic option:

```text
-XX:+UnlockDiagnosticVMOptions
-XX:+AllowUnverifiedAgentClasses
```

When enabled, semantic bytecode verification is skipped for classes supplied
through initial `ClassFileLoadHook` transformation, retransformation, and
redefinition. Mandatory class-file parsing and structural checks remain
enabled. Do not enable this option with untrusted agents or mods.

## Build Java 28+13 on Linux

Use a native Ubuntu 24.04 x64 installation. Install the build dependencies:

```bash
sudo apt-get update
sudo apt-get install -y \
  autoconf build-essential cups-common git libasound2-dev libcups2-dev \
  libfontconfig1-dev libx11-dev libxext-dev libxrandr-dev libxrender-dev \
  libxt-dev libxtst-dev openjdk-17-jdk-headless unzip zip
```

Download and extract the pinned boot JDK:

```bash
mkdir -p "$HOME/tools"
curl -fL -o "$HOME/tools/openjdk-26_linux-x64_bin.tar.gz" \
  "https://download.java.net/java/GA/jdk26/c3cc523845074aa0af4f5e1e1ed4151d/35/GPL/openjdk-26_linux-x64_bin.tar.gz"
echo "83c78367f8c81257beef72aca4bbbf8e6dac8ca2b3a4546a85879a09e6e4e128  $HOME/tools/openjdk-26_linux-x64_bin.tar.gz" |
  sha256sum -c -
tar -C "$HOME/tools" -xzf "$HOME/tools/openjdk-26_linux-x64_bin.tar.gz"
mv "$HOME/tools/jdk-26" "$HOME/tools/boot-jdk-26"
```

Build the pinned jtreg test harness:

```bash
git clone --branch jtreg-8.3+1 \
  https://github.com/openjdk/jtreg.git "$HOME/tools/jtreg-8.3.1"
bash "$HOME/tools/jtreg-8.3.1/make/build.sh" \
  --jdk /usr/lib/jvm/java-17-openjdk-amd64
```

Set the build inputs and run the build:

```bash
export BOOT_JDK="$HOME/tools/boot-jdk-26"
export BOOT_JDK_ARCHIVE="$HOME/tools/openjdk-26_linux-x64_bin.tar.gz"
export JTREG_HOME="$HOME/tools/jtreg-8.3.1/build/images/jtreg"
bash scripts/build-jdk-28-linux.sh
```

The script validates the pinned source revision, applies the version-specific
patch, builds the release image, runs the targeted jtreg test, and creates the
`dist/jdk-28+13Miko.tar.gz` binary archive, its SHA-256 file, and the complete
corresponding source archive with its checksum. The binary archive's top-level
directory is also named `jdk-28+13Miko`.

## Build Java 28+13 on Windows

Use Windows x64 with Visual Studio 2022 Build Tools and the C++ workload. These
PowerShell commands install the required toolchain:

```powershell
winget install --exact --id Microsoft.VisualStudio.2022.BuildTools `
  --accept-package-agreements --accept-source-agreements --silent `
  --override "--wait --quiet --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --addProductLang en-US"
winget install --exact --id MSYS2.MSYS2 `
  --accept-package-agreements --accept-source-agreements --silent
```

Open the **MSYS2 MSYS** shell, not a MinGW/UCRT shell, and install the POSIX
build tools:

```bash
pacman -Syu --noconfirm
pacman -S --needed --noconfirm \
  autoconf ca-certificates curl diffutils git make tar unzip zip
```

In the same shell, download the pinned boot JDK and build jtreg:

```bash
mkdir -p /c/miko-jdk-tools
curl -fL -o /c/miko-jdk-tools/openjdk-26_windows-x64_bin.zip \
  "https://download.java.net/java/GA/jdk26/c3cc523845074aa0af4f5e1e1ed4151d/35/GPL/openjdk-26_windows-x64_bin.zip"
echo "2dd2d92c9374cd49a120fe9d916732840bf6bb9f0e0cc29794917a3c08b99c5f  /c/miko-jdk-tools/openjdk-26_windows-x64_bin.zip" |
  sha256sum -c -
unzip -q /c/miko-jdk-tools/openjdk-26_windows-x64_bin.zip \
  -d /c/miko-jdk-tools
mv /c/miko-jdk-tools/jdk-26 /c/miko-jdk-tools/boot-jdk-26

git -c core.autocrlf=false clone --branch jtreg-8.3+1 \
  https://github.com/openjdk/jtreg.git /c/miko-jdk-tools/jtreg-8.3.1
bash /c/miko-jdk-tools/jtreg-8.3.1/make/build.sh \
  --jdk /c/miko-jdk-tools/boot-jdk-26
```

Set the build inputs and run the build:

```bash
export BOOT_JDK=/c/miko-jdk-tools/boot-jdk-26
export BOOT_JDK_ARCHIVE=/c/miko-jdk-tools/openjdk-26_windows-x64_bin.zip
export JTREG_HOME=/c/miko-jdk-tools/jtreg-8.3.1/build/images/jtreg
bash scripts/build-jdk-28-windows.sh
```

The Windows build creates `dist/jdk-28+13Miko-windows-x64.zip` and its
SHA-256 file. Both platform builds also create
`dist/jdk-28+13Miko-source.tar.gz` and its SHA-256 file. The source archive
contains the exact patched OpenJDK source and project build materials. The
binary archive's top-level directory is `jdk-28+13Miko`.

## Rebuilding

Both scripts clone the exact OpenJDK tag, verify its commit, validate the boot
JDK checksum and jtreg revision, apply the repository patch, run the targeted
HotSpot regression test, verify diagnostic-option locking, and package the
result. Build outputs and downloaded source trees are intentionally excluded
from Git.

GitHub Actions runs the licensing checks and both native platform builds for
pull requests and release tags. A successful `v*` tag build publishes an
early-access GitHub pre-release containing both binaries, the matching
corresponding source archive, and checksums.

## Licensing and redistribution

Original project documentation and build materials are licensed under the MIT
License in [LICENSE](LICENSE), which permits commercial and non-commercial use,
modification, and redistribution. That license does not apply to OpenJDK or
the OpenJDK-derived patch.

The JDK is based on OpenJDK `jdk-28+13`; its source files and bundled
third-party components remain subject to their own upstream licenses and
notices. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and the `legal/`
directory in each built JDK. When redistributing a binary, comply with every
applicable upstream license and include its notices. For each binary
distribution, provide the matching `jdk-28+13Miko-source.tar.gz` from the
same build and its checksum, as described in
[SOURCE-DISTRIBUTION.md](SOURCE-DISTRIBUTION.md).

This is an unofficial project and is not endorsed by Oracle or OpenJDK. Java
and OpenJDK are trademarks or registered trademarks of Oracle and/or its
affiliates.
