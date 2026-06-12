# Live555 Universal Mirror & Matrix Release Engine

This repository is a modernized, autonomous mirror of the official **Live555 Streaming Media** libraries. It combines the high-performance C++ source code from Live Networks, Inc. with a hardened CI/CD pipeline capable of delivering verified binaries across 11+ target platforms.

## 🚀 Key Features

*   **Autonomous Upstream Tracking**: Automatically checks for official Live555 releases every 6 hours.
*   **Universal Release Matrix**: Compiles and packages binaries for a wide range of architectures and operating systems.
*   **Versioned Binary Repository**: Compiled artifacts are automatically committed to the repository under `./compiled/<Version>/<OS>/` for immediate use.
*   **Staged VLC Integration**: The VLC source tree is maintained in `./source/vlc/` as a target for future builds with native Live555 support.
*   **Hardened Build System**: 
    *   **C++20 Ready**: Automatically injects modern C++ standard flags required by the latest Live555 source.
    *   **High-Reliability Fallbacks**: Gracefully handles platform-specific dependency issues (e.g., OpenSSL availability).
*   **Supply Chain Security**: All CI/CD components (GitHub Actions) are pinned to verified, immutable commit SHAs.

## 📦 Project Structure

| Directory | Description |
| :--- | :--- |
| **`./source/live555/`** | The latest mirrored source code from upstream. |
| **`./source/vlc/`** | Staged VLC source tree for integration builds. |
| **`./compiled/`** | Versioned and platform-specific binaries and libraries. |

## 📦 Supported Release Targets

The release engine currently produces verified artifacts for:

| Platform | Architecture/Variant | Build Method |
| :--- | :--- | :--- |
| **Linux** | Generic, x64, Shared Libraries | Native Toolchain |
| **Embedded** | ARM (gnueabi), Raspberry Pi | Cross-Compilation |
| **BSD** | FreeBSD, OpenBSD | Ported Toolchain |
| **Apple** | macOS (Big Sur+), iOS | Darwin Native |
| **Windows** | x86_64 | MinGW-w64 Cross-Build |

## 🛠️ Usage

### 1. Use Pre-compiled Binaries
You can find pre-compiled binaries directly in the repository under the `./compiled/` directory, or download them from the [GitHub Releases](https://github.com/Dick-s-Vault/vlc-live-555/releases) page.

### 2. Local Build Instructions
If you wish to build the source manually on your own machine:

1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/Dick-s-Vault/vlc-live-555.git
    cd vlc-live-555
    ```

2.  **Configure for Your Platform**:
    ```bash
    cd source/live555
    ./genMakefiles <platform-suffix>
    # Example: ./genMakefiles linux
    ```

3.  **Inject C++20 Support** (Required):
    The latest Live555 source uses `std::atomic_flag::test()`, which requires C++20.
    ```bash
    sed -i 's/^CPLUSPLUS_FLAGS.*/& -std=c++20/' config.<platform-suffix>
    ```

4.  **Compile**:
    ```bash
    make -j$(nproc)
    ```

## 🤖 CI/CD Pipeline

The core logic resides in `.github/workflows/universal-matrix-builder.yml`. It handles:
1.  **Upstream Check**: Compares the MD5 of `changelog.txt` against the tracked version.
2.  **Source Mirroring**: Synchronizes Live555 and VLC source trees into `./source/`.
3.  **Matrix Compilation**: Parallel execution of 11+ build jobs.
4.  **Automated Commitment**: Commits the resulting binaries back to the `main` branch.
5.  **Automated Release**: Publishes a unified GitHub Release with all artifacts.

## 🔗 Official Documentation

For core library documentation, API references, and build instructions for other exotic platforms, please visit the official Live555 website:

*   **Home Page**: [http://www.live555.com/liveMedia/](http://www.live555.com/liveMedia/)
*   **FAQ**: [http://live555.com/liveMedia/faq.html](http://live555.com/liveMedia/faq.html)

---
*Note: This repository is a community-maintained mirror. Core source code remains the property of Live Networks, Inc. Unofficial versions are not supported by the upstream maintainers.*
