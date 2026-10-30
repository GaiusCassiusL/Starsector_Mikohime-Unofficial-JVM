# Custom JDK Project Template

Complete every required field before implementation begins. Use `TBD` for
unresolved decisions and assign an owner and due date in the Open Decisions
section.

## 1. Project summary

| Field | Value |
| --- | --- |
| Project name | `Mikohime Unofficial JVM` |
| Purpose | Allow explicitly enabled agent-provided classes to run without HotSpot semantic bytecode verification |
| Status | `Linux and Windows builds previously validated; source and licensing checks pending` |

## 2. Goals and scope

### Goals

- Add one default-off JVM option that skips semantic bytecode verification for
  classes supplied by Java agents or JVMTI tooling.
- Cover initial `ClassFileLoadHook` output, retransformation, and class
  redefinition.
- Preserve upstream verification behavior unless the option is explicitly
  unlocked and enabled.
- Produce custom JDKs suitable for running Starsector.

### Non-goals

- Bypassing class-file parsing or mandatory structural checks.
- Disabling verification for ordinary classes not supplied through the covered
  agent or JVMTI paths.
- Changing unrelated HotSpot, JDK, garbage-collector, or JIT behavior.

### Constraints

- The implementation must be a narrowly scoped downstream OpenJDK change.
- Enabling the option intentionally weakens JVM type-safety guarantees for
  agent-provided classes.
- Supported agents are not yet identified and must remain an open requirement.

## 3. Target JDKs

Pin every build to an immutable upstream commit.

| Distribution | Upstream repository | Tag/version | Commit SHA | Architecture | Status |
| --- | --- | --- | --- | --- | --- |
| Mikohime Unofficial JVM 1.0.0 (28+13 EA) | `https://github.com/openjdk/jdk.git` | `jdk-28+13` | `fd9698357bb034c527c9ccdd6888a2abd75c0043` | `x64` | Planned project release tag `v1.0.0`; Linux and Windows build/test checks pass; tag release pending |

## 4. Supported platforms

| Operating system | Version | Architecture | Native toolchain | Required artifact |
| --- | --- | --- | --- | --- |
| Ubuntu | `24.04 LTS` | `x64` | GCC 13 | `.tar.gz` |
| Windows | `10/11 or Server 2016+` | `x64` | Visual Studio 2022 Build Tools | `.zip` |

State whether each platform must be built natively or may be cross-compiled:

Java 28+13 EA for Linux x64 must be built natively on Ubuntu 24.04 LTS.
Java 28+13 EA for Windows x64 must be built natively on Windows using MSYS2.

## 5. Behavioral requirements

Give each requirement a stable identifier.

| ID | Requirement | Priority | Verification method |
| --- | --- | --- | --- |
| `JDK-REQ-001` | With the custom option disabled, agent-provided classes must retain upstream forced-verification behavior. | `Must` | Automated negative test |
| `JDK-REQ-002` | With the custom option enabled, semantic bytecode verification must be skipped for bytes returned during initial `ClassFileLoadHook` processing. | `Must` | Automated javaagent/JVMTI test |
| `JDK-REQ-003` | With the custom option enabled, semantic bytecode verification must be skipped during retransformation. | `Must` | Automated JVMTI retransformation test |
| `JDK-REQ-004` | With the custom option enabled, semantic bytecode verification must be skipped during class redefinition. | `Must` | Automated JVMTI redefinition test |
| `JDK-REQ-005` | The custom option must take precedence over settings that otherwise request verification, including `-Xverify:all`. | `Must` | Automated option-precedence test |
| `JDK-REQ-006` | Class-file parsing and mandatory structural validation must remain active. | `Must` | Automated malformed-class test |
| `JDK-REQ-007` | Classes not supplied through the covered agent/JVMTI paths must retain upstream verification behavior. | `Must` | Automated control test |

### JVM option contract

| Field | Value |
| --- | --- |
| Option name | `-XX:+AllowUnverifiedAgentClasses` |
| Option type | `Diagnostic` |
| Default | `false` |
| Unlock requirement | `-XX:+UnlockDiagnosticVMOptions` |
| Supported values | Boolean: `+` enables and `-` disables |
| Scope | Initial `ClassFileLoadHook` output, retransformation, and class redefinition |
| Interaction with existing options | When enabled, this option takes precedence over verifier settings for the covered agent-provided classes and always skips their semantic bytecode verification |
| Invalid usage behavior | Use HotSpot's standard startup error for a diagnostic option supplied without `-XX:+UnlockDiagnosticVMOptions` |

### Compatibility behavior

- Default behavior: Upstream HotSpot behavior remains unchanged; covered
  agent-provided classes are forcibly verified.
- Opt-in behavior: Semantic bytecode verification is skipped for all covered
  agent-provided classes, independently of the ordinary verifier policy.
- Existing applications: Applications that do not enable the option must
  observe no behavior change.
- Existing agents and JVMTI clients: Agents using the covered load,
  retransformation, or redefinition paths may submit bytecode that would
  otherwise fail semantic verification. Structural class-file requirements
  still apply.

## 6. Security requirements

| ID | Requirement | Verification |
| --- | --- | --- |
| `SEC-001` | The custom option must be disabled by default. | Startup and behavior tests |
| `SEC-002` | Enabling the option must require diagnostic-option unlocking. | Startup option test |
| `SEC-003` | Mandatory class-file parsing and structural checks must remain enabled. | Malformed-class tests |
| `SEC-004` | Documentation must state that the option is restricted to trusted Starsector installations and trusted agents. | Documentation review |

Document:

- Threat model: The Starsector installation, mods, and enabled agents are
  trusted. Agent-provided bytecode is otherwise capable of violating JVM
  type-safety assumptions when verification is skipped.
- Security-sensitive defaults: `AllowUnverifiedAgentClasses=false`.
- Required warnings: Release documentation must warn users not to enable this
  option with untrusted agents, mods, or application code.
- Unsupported or unsafe configurations: Any use with untrusted agent or JVMTI
  input.
- Vulnerability response owner: Repository owner

## 7. Source changes

| Component/file | Intended change | Reason | Upstream issue/commit |
| --- | --- | --- | --- |
| `src/hotspot/share/classfile/classFileParser.cpp` | Preserve parsing but clear semantic-verification state for agent-transformed classes when enabled | `JDK-REQ-002`, `JDK-REQ-006` | Repository patch |
| `src/hotspot/share/prims/jvmtiRedefineClasses.cpp` | Gate explicit redefinition and retransformation verifier calls | `JDK-REQ-003`, `JDK-REQ-004` | Repository patch |
| `src/hotspot/share/runtime/globals.hpp` | Add the diagnostic, default-off JVM option | `JDK-REQ-001`, `SEC-001`, `SEC-002` | Repository patch |
| `test/hotspot/jtreg/runtime/verifier/CFLH/TestVerify.java` | Add positive, negative, precedence, and structural tests | `JDK-REQ-001` through `JDK-REQ-007` | Repository patch |

### Patch policy

- Patch format: Unified Git patch in `patches/`.
- Patch ordering: Apply the single version-specific patch to a clean checkout.
- Version-specific patches: Each upstream JDK tag requires its own reviewed
  patch.
- Upstream backports: Rebase and retest rather than applying to an unpinned
  revision.
- Patch application failure behavior: Both build scripts fail before
  configuration if the patch does not apply exactly.

## 8. Build requirements

### Common prerequisites

| Dependency | Required version | Source URL | SHA-256/signature |
| --- | --- | --- | --- |
| Boot JDK | OpenJDK `26+35` Linux x64 | `https://download.java.net/java/GA/jdk26/c3cc523845074aa0af4f5e1e1ed4151d/35/GPL/openjdk-26_linux-x64_bin.tar.gz` | `83c78367f8c81257beef72aca4bbbf8e6dac8ca2b3a4546a85879a09e6e4e128` |
| Test JDK/tool | JDK 17 for jtreg build | Ubuntu 24.04 `openjdk-17-jdk` / Windows Temurin 17 | Distribution-managed |
| Test harness | jtreg `8.3+1` | `https://github.com/openjdk/jtreg/tree/jtreg-8.3%2B1` | Git tag |

### Platform toolchains

| Platform | Compiler | Build tools | System libraries | Packaging tools |
| --- | --- | --- | --- | --- |
| Ubuntu 24.04 x64 | GCC 13 | autoconf, GNU Make, Git | ALSA, CUPS, Fontconfig, X11, Xext, Xrandr, Xrender, Xt, Xtst development packages | GNU tar, gzip, sha256sum |
| Windows x64 | MSVC from Visual Studio 2022 Build Tools | MSYS2 autoconf, GNU Make, Git | Windows SDK | MSYS2 zip, sha256sum |

### Build configuration

```text
--build=x86_64-unknown-linux-gnu
--openjdk-target=x86_64-unknown-linux-gnu
--with-debug-level=release
--with-native-debug-symbols=none
```

```text
bash scripts/build-jdk-28-linux.sh
bash scripts/build-jdk-28-windows.sh
```

Environment requirements:

| Variable | Purpose | Example |
| --- | --- | --- |
| `BOOT_JDK` | OpenJDK boot JDK | `$HOME/tools/boot-jdk-26` |
| `BOOT_JDK_ARCHIVE` | Original boot JDK archive used for SHA-256 validation | `$HOME/tools/openjdk-26_linux-x64_bin.tar.gz` |
| `JTREG_HOME` | Built jtreg image | `$HOME/tools/jtreg-8.3.1/build/images/jtreg` |
| `JTREG_SOURCE` | Optional jtreg source checkout used for tag and commit validation | `$HOME/tools/jtreg-8.3.1` |
| `WORK_DIR` | Optional Linux build workspace | `$HOME/.cache/mikohime-jdk` |
| `DIST_DIR` | Optional artifact output directory | `repository/dist` |

The Windows build uses the same variables with Windows tools exposed through
MSYS2 paths. Its boot-JDK archive is OpenJDK `26+35` Windows x64 with SHA-256
`2dd2d92c9374cd49a120fe9d916732840bf6bb9f0e0cc29794917a3c08b99c5f`.

Hardware requirements:

| Resource | Minimum | Recommended |
| --- | --- | --- |
| CPU | 4 cores | 8 or more cores |
| RAM | 8 GB | 16 GB or more |
| Free disk | 20 GB | 40 GB |

## 9. Test and validation plan

### Functional test matrix

| ID | Scenario | Configuration | Expected result | Automated |
| --- | --- | --- | --- | --- |
| `TEST-001` | Default initial agent transformation | Option omitted | Verification rejects invalid semantic bytecode | `Yes` |
| `TEST-002` | Enabled initial agent transformation | Custom option enabled | Semantic verifier is skipped | `Yes` |
| `TEST-003` | Enabled retransformation | Custom option enabled | Semantic verifier is skipped | `Yes` |
| `TEST-004` | Enabled class redefinition | Custom option enabled | Semantic verifier is skipped | `Yes` |
| `TEST-005` | Force-verification precedence | Custom option enabled with `-Xverify:all` | Custom option wins for covered agent classes | `Yes` |
| `TEST-006` | Ordinary invalid class | Custom option enabled | Upstream verifier behavior remains active | `Yes` |
| `TEST-007` | Structurally malformed agent class | Custom option enabled | Class-file parser rejects the class | `Yes` |
| `TEST-008` | Diagnostic option remains locked | Unlock option omitted | JVM startup rejects the option | `Yes` |

Include applicable coverage for:

- Default upstream behavior
- Custom option enabled and disabled
- Every supported option combination
- Initial class loading
- Agent transformation
- Retransformation
- Class redefinition
- Bootstrap, platform, and application class loaders
- Structurally malformed class files
- Unsupported option values
- Startup option reporting

### Build validation

- Clean Linux build: `bash scripts/build-jdk-28-linux.sh`
- Clean Windows build: `bash scripts/build-jdk-28-windows.sh`
- Targeted tests: Run automatically by each build script using
  `TEST=test/hotspot/jtreg/runtime/verifier/CFLH/TestVerify.java`.
- Required upstream test suites: The targeted modified HotSpot test.
- Binary smoke test: Run automatically with the unlocked custom option.
- JVM option inspection: The scripts verify that the diagnostic option works
  when unlocked and is rejected when locked.

### Release validation

| Check | Acceptance criterion |
| --- | --- |
| Version metadata | `28-ea+13-mikohime-agent-verification` |
| Source revision | `fd9698357bb034c527c9ccdd6888a2abd75c0043` |
| Custom behavior | Covered agent classes bypass semantic verification only when enabled |
| Default behavior | Invalid agent-provided classes fail verification |
| Archive integrity | A SHA-256 sidecar is generated for every archive |
| Archive contents | Complete OpenJDK image rooted at `jdk-28+13Miko` |
| Native dependencies | Standard dependencies produced by the native OpenJDK build |

## 10. Packaging and distribution

### Artifact naming

```text
jdk-28+13Miko.tar.gz
jdk-28+13Miko-windows-x64.zip
```

The archive's top-level directory must be `jdk-28+13Miko`.

### Required release files

- JDK archive
- SHA-256 checksum
- Matching complete corresponding source archive and SHA-256 checksum
- Applicable upstream licenses and third-party notices
- Release notes
- License and third-party notices
- Corresponding source and patch references
- SBOM or signature when required by the release channel

Distribution location and retention:

GitHub Releases; release retention follows repository policy.

## 11. Reproducibility and provenance

- Immutable source revisions: Build only the tag and commit recorded in this
  document and the scripts.
- Verified dependency checksums: Boot-JDK archives are checked before use.
- Pinned build inputs: jtreg is validated by tag and commit.
- Build timestamp handling: Set `SOURCE_DATE_EPOCH` and OpenJDK's
  `--with-source-date` to the pinned upstream commit timestamp.
- Archive ordering and metadata normalization: Linux tar entries and timestamps
  are normalized; Windows ZIP timestamps are set from the source commit and
  extra attributes are omitted.
- Build logs and attestations: Retain logs with release builds when available.
- Rebuild comparison method: Compare generated SHA-256 sidecars from two clean
  builds on the same supported toolchain.

## 12. CI/CD requirements

| Stage | Trigger | Platforms | Required result |
| --- | --- | --- | --- |
| Licensing/source validation | Push and pull request | Ubuntu 24.04 | Project license scope, third-party notices, source instructions, and shell syntax pass |
| Patch validation | Push, pull request, and release tag | Linux and Windows x64 | Patch applies to the pinned commit |
| Build | Push, pull request, and release tag | Linux and Windows x64 | Native JDK image completes |
| Test | Each build | Linux and Windows x64 | Targeted jtreg test and diagnostic-option checks pass |
| Package | Successful build and test | Linux and Windows x64 | Binary and complete source archives plus SHA-256 sidecars created |
| Release | Maintainer approval | GitHub | Both platform artifacts published |

Define:

- Failure handling: Fail fast; do not package after a validation failure.
- Artifact retention: GitHub release policy.
- Release approval: Repository maintainer.
- Secret requirements: None for local builds.

## 13. Documentation requirements

- Installation instructions
- JVM option reference
- Security warning and trust assumptions
- Migration and rollback instructions
- Supported-version policy
- Known limitations
- Build-from-source instructions
- License and source-availability information

## 14. Risks and mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Verification bypass is enabled with untrusted agents | Medium | High | Keep the option diagnostic, default-off, and document the trust boundary | Project owner |
| Upstream source changes invalidate the patch | High | Medium | Pin the exact commit and fail patch validation | Project owner |
| Platform toolchain drift changes binaries | Medium | Medium | Record toolchains and compare clean-build checksums | Project owner |

## 15. Open decisions

| ID | Decision needed | Options | Owner | Due date | Resolution |
| --- | --- | --- | --- | --- | --- |
| `DEC-001` | Should release artifacts be signed? | Code signing, detached signatures, checksums only | Project owner | Before public release | Checksums only for initial builds |

## 16. Acceptance criteria

- [x] All target JDK versions and source commits are pinned.
- [x] All supported platforms and toolchains are defined.
- [x] Behavioral and security requirements are defined.
- [x] Default behavior remains secure and backward-compatible as specified.
- [x] Every required option combination has an automated test.
- [x] Native release builds complete successfully.
- [x] Required project-specific tests pass.
- [x] Artifacts pass integrity and smoke checks.
- [ ] Checksums, licenses, notices, and source references are published.
- [ ] Matching complete corresponding source archives and checksum sidecars are attached to the release.
- [ ] Installation, usage, security, and rollback documentation is complete.
- [ ] Release approval is recorded.

## 17. Deliverables

| Deliverable | Owner | Location | Status |
| --- | --- | --- | --- |
| Requirements | Project owner | `PROJECT_TEMPLATE.md` | Complete for JDK 28+13 |
| Source patches | Project owner | `patches/` | Complete for JDK 28+13 |
| Build automation | Project owner | `scripts/` | Linux and Windows validated |
| Test results | Project owner | Build-local jtreg reports | Passing |
| Release artifacts | Project owner | `dist/` locally; GitHub Releases when published | Built locally |
| Release documentation | Project owner | `README.md` | Build instructions complete |
