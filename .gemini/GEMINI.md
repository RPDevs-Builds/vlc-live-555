# Live555 Multi-Platform Matrix Release Engine — Context & Directives

This document serves as the ground-truth technical specification and operational constraint layout for managing the Live555 upstream mirror and automated multi-platform compilation pipeline via `gemini-cli`.

## 1. Architectural Taxonomy
* **Established:** Upstream Live555 relies on static configuration templates (`config.<suffix>`) and custom shell parsing mechanics (`./genMakefiles`) rather than dynamic build tools like CMake or Autotools.
* **Contested:** Upstream code modifications introduce hard modern standard dependencies (e.g., C++20 `std::atomic_flag::test()`) without explicitly migrating the base configuration file compiler flags out of legacy defaults (C++11/C++14).
* **Inferred:** Cross-compilation workflows executing on standardized virtualization blocks (such as GitHub host runners) require explicit pre-provisioning of specific multi-architecture cross-compiler binaries (`gcc-arm-linux-gnueabi`, `mingw-w64`) to survive template execution faults.

---

## 2. Core Build Mechanics & Dependencies
The matrix processing engine relies on three operational stages to process upstream updates into platform-specific tarballs without bloating repository history or polluting tracking state.

### A. The Upstream Tracking Sync Loop
* The state machine tracks upstream releases deterministically by fetching the authoritative changelog asset (`/changelog.txt`) into transient space (`/tmp`).
* The system evaluates changes via MD5 validation rules against `.github/tracking/changelog.md5`.
* If a delta is identified, it executes an explicit `rsync --delete` routine to clear the repository baseline, mirrors the pristine upstream code directly into the `main` branch, and applies a precise version-matching Git tag (`vYYYY.MM.DD`).

### B. Universal C++20 Flag Injection
* To patch compile regressions like the `std::atomic_flag::test()` issue, the matrix target switches execution to find the `COMPILE_OPTS` definition within the targeted platform template (`config.${{ matrix.suffix }}`) and appends `-std=c++20`.
* This transformation must happen inside the discrete job space per platform to maintain clean boundary layers.

### C. Isolated Compilation & Staging Topology
* **Compute Isolation:** Toolchain execution runs concurrently using distinct host runners matching the binary requirements (e.g., `ubuntu-latest` for ELF and Windows targets, `macos-latest` for native Mach-O targets).
* **Deterministic Path Allocation:** Binaries route from compilation loops via `make install DESTDIR="$(pwd)/local_staging" PREFIX=/usr/local`. 
* Staged workspaces are compressed into standalone platform tarballs (`live555-${TARGET}-${VERSION}.tar.gz`) and published cleanly as immutable assets on the GitHub Releases page tied to the matching version tag.

---

## 3. Maintenance Protocols & System Constraints

### Protocol 1: Supply Chain Isolation
* All third-party GitHub Actions blocks must remain pinned to explicit, immutable commit SHAs rather than mutable version tags to protect the continuous compilation tree against upstream supply chain manipulation.
* Global repository permissions are structurally dropped to `read-only`. Elevated `write` parameters are scoped exclusively to tasks responsible for branch state increments or release generation.

### Protocol 2: Local Reference Cleanups
* The legacy `live555/` tracking subdirectory contains local configuration baselines used to determine cross-compiler requirements. 
* Once the event-driven workflow engine (`universal-matrix-builder.yml`) successfully drops a validated target deployment release containing all required platform architectures, the local `live555/` reference folder can be purged to minimize workspace footprint.

### Protocol 3: Explicit Target Rules
* Do not merge the output naming logic into standard host definitions. The path matrix layout rules require that `config.linux-64bit` maps explicitly and cleanly onto target artifact paths named `linux-64bit`, while alternate loops drop into their lowercase structural token aliases (`armlinux`, `mingw`, `macosx-bigsur`).
