# GitHub Build Fleet: Architecture & Infrastructure Guide

This guide details the multi-tiered GitHub build system used for high-performance, cross-platform compilation of Kodi and its primary add-ons. It is designed to be portable to other `gemini-cli` projects requiring a "Hub-Builder-Distributor" model.

---

## 1. Architecture Overview

The fleet operates across three distinct repository tiers. This high-complexity model is specifically designed for large projects (e.g., Kodi Core) where a single repository would face rate limits or resource exhaustion.

### 1.1 Decision Rationale: Why a Tiered System?
- **Isolation of Heavy Builds**: C++ builds for 4+ operating systems can trigger GitHub Actions concurrent job limits. Moving them to individual "Builder" repos provides independent job queues.
- **Artifact Management**: Large binary assets can bloat the `.git` history of a primary repo. Using separate "Distributor" repositories keeps the Hub and Builders lean and responsive.
- **OS-Level Granularity**: When a build fails on one OS (e.g., macOS code-signing), it doesn't block the release cycle or CI/CD pipelines of the Hub or other platforms.

### 1.2 Scale & Justification: When is this Overkill?
**Warning**: This system carries significant maintenance overhead (API-driven updates, 30+ repositories).
- **Use this if**: You are building a complex project for **3+ Operating Systems**, have build times exceeding **1 hour**, or need to host **multi-gigabyte binary releases**.
- **Avoid this if**: You are building a web app, a single-OS binary, or a small library. A single repository with standard Matrix jobs is sufficient for 95% of projects.

### Tier 1: The Hub (`kodi-build`)
- **Role**: Command and Control.
- **Functions**:
    - Stores the fleet manifest (`sources.yaml`).
    - Orchestrates the entire fleet via `orchestrate-fleet.yml`.
    - Manages local runner registration scripts.
    - Monitors the fleet via `monitor.zsh`.

### Tier 2: The Builders (e.g., `xbmc-build`, `inputstream.adaptive-build`)
- **Role**: Compilation & Packaging.
- **Functions**:
    - Clones upstream source code.
    - Executes heavy C++ compilation using local or hosted runners.
    - Uploads artifacts directly to Tier 3 (Distributors).

### Tier 3: The Distributors (e.g., `xbmc-build-win64`, `xbmc-build-linux64`)
- **Role**: Artifact Hosting & Release.
- **Functions**:
    - Receives compiled binaries via `workflow_dispatch` or `gh release`.
    - Acts as a permanent host for binary releases for specific OS/Architecture pairs.

---

## 2. OS-Specific Build Logic

We use a unified build approach centered around Kodi's internal `depends` system to ensure consistency across the fleet.

### Linux (Ubuntu 22.04)
- **Method**: Native CMake.
- **Logic**: Uses pre-installed system libraries (`libudev-dev`, `libgbm-dev`, etc.) inside the builder image.
- **Flags**: `-DAPP_RENDER_SYSTEM=gl`.

### Cross-Platform (Windows, Android, macOS)
- **Method**: `tools/depends` Bootstrapping.
- **Workflow**:
    1.  `cd source/xbmc/tools/depends && ./bootstrap`
    2.  `./configure --prefix=$(pwd)/../../../../xbmc-deps $CONFIG_FLAGS`
    3.  `make -j$(nproc)`
    4.  The main CMake build then uses `-DCMAKE_PREFIX_PATH=$(pwd)/../xbmc-deps`.
- **Target Triplets**:
    - **Windows 64**: `--host=x86_64-w64-mingw32 --with-platform=windows`
    - **Android ARM64**: `--host=aarch64-linux-android --with-platform=android`
    - **OSX 64**: `--with-platform=macos`

---

## 3. Local Runner Infrastructure (The "Runner Farm")

### 3.1 Rationale: Why Self-Hosted?
- **Unlimited Build Time**: GitHub-hosted runners have a 6-hour limit and are billed per minute. Heavy C++ builds are more cost-effective on local high-IO hardware.
- **Pre-Caching**: We "pre-bake" multi-gigabyte SDKs (Android, MinGW) into Docker images. This eliminates download/extract time (approx. 15 mins saved per run) compared to hosted runners.
- **Full Environment Control**: Some platforms (like Android) require specific system-level tweaks that are restricted on GitHub's shared runners.

### 3.2 Tools Used
- **GitHub CLI (`gh`)**: Core for repository creation, API interaction, and release management.
- **Docker & Docker Compose**: Isolates build environments and standardizes runner deployment.
- **Python (with `subprocess` & `base64`)**: Used for "Mass Management"—automating code changes across 30+ repositories via the GitHub API.
- **`yq`**: Parses the `sources.yaml` manifest to dynamically generate build matrices.
- **`ccache`**: Drastically reduces incremental build times by caching C++ object files across runs.

### Deployment (`docker-compose.yml`)
```yaml
services:
  kodi-linux-builder:
    image: runners_linux-builder:latest
    volumes:
      - /mnt/largedata/github_runners/linux-builder/work:/home/runner/_work
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - RUNNER_NAME=kodi-local-linux
      - GH_ORG=RPDevs-Builds
      - GH_TOKEN=${GH_PAT}
```

---

## 4. Automation & Maintenance

The fleet is maintained via API-driven Python scripts to ensure workflow parity across 30+ repositories.

### `_update_workflows_api.py`
This script uses the GitHub API to forcefully update the `.github/workflows/build.yml` file across all builder repositories. It injects:
- Updated runner labels.
- Conditional dependency installation logic.
- Standardized release naming conventions (`xbmc-linux64-v21.0-Piers.zip`).

### `monitor.zsh`
A real-time dashboard that uses parallel background `gh run list` calls to provide a matrix view of the entire organization's build health.

---

## 5. Lessons Learned & Heuristics

- **Pre-bake Dependencies**: Avoid `sudo apt install` during workflow runs on self-hosted runners. This prevents "no new privileges" errors and significantly reduces build time.
- **Explicit Platform Flags**: Kodi's `configure` script often fails to auto-detect cross-compile targets. Always provide `--with-platform` and `--host` explicitly.
- **Version Alignment**: Keep the Dockerized runner version synced with GitHub's latest (e.g., `2.335.1`) to avoid startup delays due to self-updates.
---

## 6. Build Workflow Breakdown (`build.yml`)

The following is the core logic used across all Builder repositories. Each section is annotated with the technical reasoning behind its design.

### 6.1 Matrix Orchestration
```yaml
setup-matrix:
  runs-on: ubuntu-latest
  outputs:
    matrix: ${{ steps.set-matrix.outputs.matrix }}
  steps:
    - id: set-matrix
      run: |
        # Dynamically handles the 'both' branch input from the Hub
        if [ "${{ github.event.inputs.branch_input }}" == "both" ]; then
          echo 'matrix={"branch": ["Piers", "Omega"], "platform": ["linux64", "win64", "android-arm64", "osx64"]}' >> $GITHUB_OUTPUT
        else
          echo 'matrix={"branch": ["${{ github.event.inputs.branch_input }}"], "platform": ["linux64", "win64", "android-arm64", "osx64"]}' >> $GITHUB_OUTPUT
        fi
```
**Note**: We use a pre-job to generate the matrix. This allows the Hub to trigger a single workflow that fans out into 8+ independent build jobs.

### 6.2 Host-Aware Runner Selection
```yaml
runs-on: ${{ (matrix.platform == 'osx64' && 'macos-latest') || (matrix.platform == 'linux64' && fromJSON('["self-hosted", "linux64"]')) || fromJSON('["self-hosted", "lightweight"]') }}
```
**Note**: This ternary logic intelligently routes jobs. `osx64` must use GitHub's macOS runners (required for Xcode), while `linux64` (heavy C++) and other platforms (lightweight packaging) use specific local runner pools.

### 6.3 Conditional Dependency Management
```yaml
- name: Install System Dependencies
  if: ${{ !contains(runner.labels, 'self-hosted') }}
  run: |
    # Only runs on GitHub-hosted runners (macOS)
    # Self-hosted Docker runners have these pre-baked to avoid 'no new privileges' errors
    sudo apt update && sudo apt install -y ...
```
**Note**: This is critical for security. We avoid `sudo` in Docker containers during the workflow, relying instead on the pre-built image state.

### 6.4 The Unified Build Loop
```bash
if [ "${{ matrix.platform }}" == "linux64" ]; then
  # Native build for the host OS
  cmake ../source/xbmc -DCMAKE_INSTALL_PREFIX=../$OUT_DIR -DAPP_RENDER_SYSTEM=gl
  make -j$(nproc) install
else
  # Cross-compilation using the internal 'depends' system
  cd source/xbmc/tools/depends
  ./bootstrap
  ./configure --prefix=$(pwd)/../../../../xbmc-deps $CONFIG_FLAGS
  make -j$(nproc)
  cd ../../../
  # Use the generated dependencies for the main Kodi build
  cmake ../source/xbmc -DCMAKE_INSTALL_PREFIX=../$OUT_DIR -DCMAKE_PREFIX_PATH=$(pwd)/../xbmc-deps
fi
```
**Note**: This "Double-Pass" build (Depends first, then App) guarantees that regardless of the host OS, we have the exact library versions required by the target platform.

### 6.5 Remote Dispatch
```bash
DIST_REPO="RPDevs-Builds/xbmc-build-${{ matrix.platform }}"
gh release create "$TAG" $FILE --repo "$DIST_REPO" ...
```
**Note**: Using the `gh` CLI with a cross-repository `GH_PAT` allows a Builder to "push" its success directly to its designated Distributor repository, completing the tiered lifecycle.

---

## 7. Fleet Monitoring (`monitor.zsh`)

The `monitor.zsh` script provides a real-time, terminal-based dashboard for the entire organization. It is optimized for speed and high-density information display.

### 7.1 Parallel Data Fetching
```zsh
tmp_file=$(mktemp)
for entry in "${builders[@]}"; do
    fetch_status "$entry" >> "$tmp_file" &
done
wait
```
**Note**: The script iterates through the list of builder repositories and launches a background job (`&`) for each. This allows the dashboard to query GitHub's API for 30+ repositories in parallel, significantly reducing the refresh time from minutes to seconds.

### 7.2 Matrix Status Extraction
```zsh
local jobs_data=$(gh run view --repo RPDevs-Builds/$repo $id --json jobs 2>/dev/null)

# Platform Matrix Logic
local p_linux=$(echo $jobs_data | jq -r '.jobs[] | select(.name | contains("linux64")) | "\(.status)|\(.conclusion)"')
local p_win=$(echo $jobs_data | jq -r '.jobs[] | select(.name | contains("win64")) | "\(.status)|\(.conclusion)"')
...
```
**Note**: Instead of just showing "success" or "failure" for the whole run, the script parses the individual jobs within the workflow. This allows the dashboard to display the status of each OS (Linux, Windows, Android, OSX) in a compact grid using `jq`.

### 7.3 Visual Formatting (Zsh Colors)
```zsh
GREEN='%F{green}'
RED='%F{red}'
YELLOW='%F{yellow}'
BLUE='%F{blue}'
NC='%f' 

format_job() {
    ...
    [[ "$c" == "success" ]] && echo "${GREEN}●${NC}" || echo "${RED}●${NC}"
}
```
**Note**: We use native Zsh color escape sequences (`%F{color}`) rather than standard ANSI codes. This ensures a cleaner implementation and prevents visual glitches when resizing terminal windows.

### 7.4 Active Step Detection
```zsh
local current_step=$(echo $jobs_data | jq -r '.jobs[] | select(.name != "setup-matrix") | .steps[] | select(.status != "completed") | .name' | head -n 1)
```
**Note**: The dashboard dynamically identifies which step is currently executing (e.g., "Build and Package") across all platforms. This provides immediate insight into where a build is stuck without needing to visit the GitHub web UI.
