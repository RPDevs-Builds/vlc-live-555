# VLC & Live555 Automated Build Engine

## Overview
This repository automates the cross-compilation and packaging of [Live555](https://www.live555.com/) and [VLC Media Player](https://www.videolan.org/vlc/) for a wide array of platforms and architectures.

## Architecture
We utilize a dual-track CI/CD pipeline:
1.  **Live555 Matrix Builder**: Tracks upstream releases, compiles static libraries (`.a`) targeting diverse architectures, and archives raw binaries.
2.  **VLC Matrix Builder**: Cross-compiles VLC, linking dynamically to the pre-compiled Live555 static libraries. It generates both raw binary tarballs and platform-native installers.

## Binary Artifact Structure
All compiled artifacts (both raw binaries and native installers) are committed to the repository and attached to the GitHub Release page using the following hierarchical convention:

```text
compiled/
└── <OS>/              # (e.g., linux, mingw, macosx-bigsur)
    ├── live555/
    │   └── <Version>/ # Raw Live555 binaries and installers
    └── vlc/
        └── <Version>/ # Raw VLC binaries and native installers
```

## Build Guide
### 1. Automated Pipeline
The build pipeline is triggered automatically via:
- **Schedule**: Every 6 hours to check for upstream Live555 changes.
- **Push**: Any commit to the `main` branch triggers a full build of VLC.
- **Manual**: Trigger a build via GitHub Actions "Workflow Dispatch" for specific tracks (`dev`, `stable`, or `both`).

### 2. Self-Hosted Runner Infrastructure
To handle heavy compilation tasks, we use a custom Docker-based GitHub Actions runner. The infrastructure configuration is located under `./github-runners/`.

#### Setting up a local runner:
1. Ensure `docker` and `docker-compose` are installed.
2. Navigate to `./github-runners/`.
3. Run `docker-compose up -d` to spin up the registered self-hosted runner.
4. The runner is pre-configured with the necessary cross-compilation toolchains (`mingw-w64`, `gcc-arm-linux-gnueabi`, etc.).

## Feature Guide: Hardware Acceleration
To ensure the best playback performance on Linux using our builds, please enable hardware acceleration manually:
1. Open **Tools** > **Preferences**.
2. Switch to the **Input / Codecs** tab.
3. Under **Hardware-accelerated decoding**, select **VA-API** (for Intel/AMD) or the appropriate option for your GPU.
4. Click **Save** and restart VLC.
*Note: Ensure your system has the appropriate drivers (e.g., `intel-media-va-driver`) installed.*

