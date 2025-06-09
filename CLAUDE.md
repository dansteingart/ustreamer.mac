# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

µStreamer is a lightweight MJPEG streaming server designed for high-performance video streaming from V4L2 devices. Part of the PiKVM project, it specializes in streaming VGA/HDMI screencast hardware with high resolution and FPS. Key advantages over mjpg-streamer include multithreaded JPEG encoding, hardware acceleration, better device disconnect handling, and frame deduplication for bandwidth optimization.

## Build Commands

### Basic Build
```bash
make                    # Build main binaries
make apps              # Build only core applications
make clean             # Clean all build artifacts
```

### macOS Build
```bash
# Install dependencies via Homebrew:
brew install libjpeg-turbo libevent pkg-config

# Build with macOS-compatible settings:
make apps MK_WITH_PTHREAD_NP= MK_WITH_SETPROCTITLE= MK_WITH_PDEATHSIG=

# For development builds (from src/ directory):
cd src/
make MK_WITH_PTHREAD_NP= MK_WITH_SETPROCTITLE= MK_WITH_PDEATHSIG=
```

### Optional Components (Linux only)
```bash
make WITH_PYTHON=1     # Build with Python bindings
make WITH_JANUS=1      # Build with Janus WebRTC plugin
make WITH_V4P=1        # Build V4L2 to DRM bridge
make WITH_GPIO=1       # Build with GPIO signaling support
make WITH_SYSTEMD=1    # Build with systemd integration
```

### Code Quality & Testing
```bash
make tox               # Run comprehensive linting (Docker-based)
make linters           # Build linter Docker image
make clean-all         # Deep clean including linter artifacts
```

### Installation
```bash
make install           # Install to /usr/local (or PREFIX)
make install-strip     # Install with stripped binaries
```

### Development Utilities
```bash
make regen             # Regenerate embedded HTML/icon files
```

## Architecture Overview

### Core Threading Model
- **Main Thread**: Stream capture and encoding coordination
- **HTTP Thread**: Asynchronous HTTP server using libevent
- **Worker Pool**: Configurable multithreaded JPEG encoding
- **Ring Buffer**: Thread-safe circular buffer for frame management

### Key Data Flow
```
V4L2 Device / macOS Camera → Capture → Ring Buffer → Encoder Workers → HTTP Server → Clients
                              ↓
                          Memory Sinks (for Janus/Python extensions)
```

### Core Components
- **Capture System** (`src/libs/capture.c/h`): V4L2 interface with hardware buffer management, includes macOS AVFoundation support
- **Encoder System** (`src/ustreamer/encoder.c/h`): Supports CPU, hardware, and M2M encoding
- **Streaming** (`src/ustreamer/stream.c/h`): Ring buffer and worker pool management
- **HTTP Server** (`src/ustreamer/http/server.c/h`): libevent-based MJPEG streaming
- **macOS Camera** (`src/libs/macos_camera.m/h`): AVFoundation-based camera capture for macOS

### Directory Structure
- **`src/libs/`**: Shared libraries (capture, frame management, utilities)
- **`src/ustreamer/`**: Main application with encoders and HTTP server
- **`src/ustreamer/encoders/`**: Multiple encoding implementations (cpu/, hw/)
- **`src/dump/`**: Video stream capture utility
- **`janus/`**: Janus WebRTC plugin for H.264 streaming
- **`python/`**: Python bindings for µStreamer functionality

### Frame Management
- **`us_frame_s`**: Core frame structure with metadata
- **`us_ring_s`**: Thread-safe producer-consumer ring buffer
- **Memory Sinks**: Shared memory interface for external consumers

## Testing Approach

No traditional unit tests - uses comprehensive static analysis:
- **cppcheck**: C code security and style analysis
- **flake8, pylint, mypy**: Python code quality
- **vulture**: Dead code detection
- **htmlhint**: Web interface validation
- **Docker-isolated**: All linting runs in containers via `make tox`

## Common Development Patterns

### Encoder Selection
- **CPU**: Software JPEG encoding using libjpeg
- **M2M-IMAGE/M2M-VIDEO**: Hardware V4L2 Memory-to-Memory encoding
- **HW**: Platform-specific hardware acceleration

### Configuration Features
- **Frame Deduplication**: `--drop-same-frames=N` for bandwidth optimization
- **DV-timings**: Dynamic resolution changes from source signal
- **Device Persistence**: Graceful handling of device disconnection
- **Memory Sinks**: External process integration via shared memory

### Build Feature Flags
Use environment variables to enable optional components:
- `WITH_PYTHON=1`: Python bindings support (Linux only)
- `WITH_JANUS=1`: H.264 WebRTC streaming via Janus (Linux only)
- `WITH_GPIO=1`: GPIO signaling for stream state (Linux only)
- `WITH_SYSTEMD=1`: Systemd socket activation (Linux only)
- `WITH_PTHREAD_NP=0`: Disable pthread extensions (required for macOS)
- `WITH_SETPROCTITLE=0`: Disable process title setting (required for macOS)
- `WITH_PDEATHSIG=0`: Disable parent death signal (required for macOS)

### macOS Camera Support
µStreamer now includes full native camera support on macOS via AVFoundation:

#### Features
- **Native Camera Access**: Uses AVFoundation for real camera capture (not just development)
- **Multiple Camera Support**: Automatically detects and allows selection of available cameras
- **Format Support**: YUYV format with proper color reproduction
- **Resolution Control**: Configurable resolution and frame rate settings
- **Stable Streaming**: Proper buffer management without V4L2 dependencies

#### Usage
```bash
# List available cameras (check logs)
./ustreamer --device 0 --port 8080

# Select specific camera by index
./ustreamer --device 1 --port 8080  # FaceTime HD Camera
./ustreamer --device 2 --port 8080  # External USB camera

# Custom resolution and settings
./ustreamer --device 0 --resolution 1280x720 --port 8080 --host 0.0.0.0
```

#### Technical Implementation
- **V4L2 Compatibility Layer**: `src/libs/macos_v4l2_stub.h` provides compilation compatibility
- **AVFoundation Integration**: `src/libs/macos_camera.m` handles native camera operations
- **Conditional Compilation**: macOS-specific features enabled with `WITH_MACOS_CAMERA` flag
- **Buffer Management**: Custom buffer handling to avoid V4L2 ioctl operations

### macOS Limitations
- **Hardware Encoding**: M2M and DRM features are disabled (Linux kernel only)
- **Optional Components**: Python bindings, Janus, GPIO, and systemd features are not supported
- **V4L2 Features**: Some advanced V4L2 controls not available (expected)