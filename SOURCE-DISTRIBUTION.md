# Corresponding source and release compliance

Every binary release produced by either build script is accompanied locally by:

- `jdk-28+13Miko-source.tar.gz`: the complete corresponding OpenJDK source
  tree at the pinned upstream commit, with the project patch applied, plus
  project build scripts, workflow, patch, license, and notices.
- A SHA-256 sidecar for the source archive.
- The JDK archive, which retains the upstream `LICENSE`, `README`, and `legal/`
  notices, plus its SHA-256 sidecar.

The source archive is intended to accompany each binary when distributed.
When publishing a release, upload the source archive and all checksum sidecars
alongside the platform binaries, and link this file and `THIRD_PARTY_NOTICES.md`
from the release description. Keep the source download available from the same
release location as the binary.

The pinned source URL and revision are documented in `README.md` and embedded
in the source archive. The archive includes the exact changed OpenJDK source
and the unified patch so recipients can review and rebuild the modified JDK.
Build scripts identify pinned tool versions and validate boot-JDK checksums.

This repository uses MIT for its original documentation and build materials
only. The OpenJDK-derived patch and source remain under the upstream licenses
and notices that apply to them; the MIT license does not replace those terms.

Before each release, verify that both platform binaries contain the upstream
`legal/` directory and license files, that all three archives and their SHA-256
sidecars are attached, and that this source archive corresponds to the exact
source revision and patch used for those binaries.
