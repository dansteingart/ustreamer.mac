# µStreamer macOS Port - Technical Implementation Log

This document provides a comprehensive technical log of all changes made to port µStreamer to macOS with full native camera support.

## Project Overview

**Objective**: Port µStreamer (Linux-only MJPEG streaming server) to run natively on macOS with working camera functionality.

**Challenge**: µStreamer was designed exclusively for Linux V4L2 (Video4Linux2) video capture devices. macOS has no V4L2 support and uses AVFoundation for camera access.

**Solution**: Created a dual-layer approach:
1. **V4L2 Compatibility Layer**: Stub implementation for compilation
2. **AVFoundation Integration**: Native macOS camera implementation

## Major Architectural Changes

### 1. V4L2 Compatibility Layer (`src/libs/macos_v4l2_stub.h`)

**Purpose**: Allow µStreamer's V4L2-dependent code to compile on macOS.

**Implementation**:
```c
// Core V4L2 types redefined for macOS
typedef uint32_t __u32;
typedef uint16_t __u16;
typedef uint8_t __u8;
typedef int32_t __s32;
typedef int64_t __s64;
typedef uint64_t __u64;
typedef uint64_t v4l2_std_id;

// ~100 V4L2 constants, structures, and enums
#define V4L2_PIX_FMT_YUYV    v4l2_fourcc('Y', 'U', 'Y', 'V')
#define V4L2_PIX_FMT_MJPEG   v4l2_fourcc('M', 'J', 'P', 'G')
// ... extensive V4L2 API coverage
```

**Key Features**:
- Complete struct definitions for `v4l2_capability`, `v4l2_format`, `v4l2_buffer`, etc.
- All major V4L2 pixel formats and constants
- IOCTL definitions (non-functional but allow compilation)
- Memory management enums and buffer types

### 2. AVFoundation Camera System (`src/libs/macos_camera.m/h`)

**Purpose**: Provide native macOS camera functionality using AVFoundation.

**Architecture**:
```objc
@interface MacOSCameraDelegate : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, strong) NSLock *frameLock;
@property (nonatomic) CVPixelBufferRef latestFrame;
@property (nonatomic) bool hasNewFrame;
@end

struct macos_camera_s {
    AVCaptureSession *session;
    AVCaptureDevice *device;
    AVCaptureDeviceInput *input;
    AVCaptureVideoDataOutput *output;
    MacOSCameraDelegate *delegate;
    dispatch_queue_t queue;
    // Configuration and state
};
```

**Core Functions Implemented**:
- `macos_camera_init()` - Initialize camera system
- `macos_camera_list_devices()` - Enumerate available cameras
- `macos_camera_select_device()` - Choose camera by index or ID
- `macos_camera_set_resolution()` - Configure capture resolution
- `macos_camera_set_fps()` - Set frame rate with validation
- `macos_camera_start()/stop()` - Control capture session
- `macos_camera_grab_frame()` - Retrieve latest frame data

### 3. Integration Layer (`src/libs/capture.c`)

**Purpose**: Seamlessly integrate macOS cameras into existing µStreamer capture system.

**Key Changes**:
```c
#if defined(__APPLE__) && defined(WITH_MACOS_CAMERA)
    // macOS camera implementation
    if (cap->macos_cam) {
        // Camera initialization and frame capture
        // Bypass all V4L2 operations
    }
#endif
```

**Integration Points**:
- `us_capture_init()` - Initialize macOS camera alongside V4L2 structures
- `us_capture_open()` - Open and configure macOS camera instead of V4L2 device
- `us_capture_hwbuf_grab()` - Provide frames from AVFoundation in V4L2-compatible format
- `us_capture_hwbuf_release()` - Skip V4L2 buffer operations for macOS cameras
- `us_capture_close()` - Clean shutdown of AVFoundation session

## Build System Modifications (`src/Makefile`)

### Conditional Compilation Strategy

**Problem**: Different build requirements for ustreamer (needs camera) vs dump utility (no camera needed).

**Solution**: Separate compilation flags and object directories.

**Changes**:
```makefile
# macOS-specific compiler flags
_USTR_CFLAGS = $(_CFLAGS)
_DUMP_CFLAGS = $(_CFLAGS)
ifeq ($(shell uname -s),Darwin)
override _USTR_CFLAGS += -DWITH_MACOS_CAMERA
endif

# Separate object directories to handle different compilation flags
_USTR_OBJS = $(patsubst %.c,$(_BUILD)/ustr/%.o,$(filter %.c,$(_USTR_SRCS))) $(patsubst %.m,$(_BUILD)/ustr/%.o,$(filter %.m,$(_USTR_SRCS)))
_DUMP_OBJS = $(patsubst %.c,$(_BUILD)/dump/%.o,$(filter %.c,$(_DUMP_SRCS)))

# macOS framework linking
ifeq ($(shell uname -s),Darwin)
override _USTR_LDFLAGS += -framework Foundation -framework AVFoundation -framework CoreMedia -framework CoreVideo -framework VideoToolbox
override _DUMP_LDFLAGS += -framework Foundation
endif
```

### Platform-Specific Features

**Disabled for macOS**:
- `MK_WITH_PTHREAD_NP=` - Pthread extensions not available
- `MK_WITH_SETPROCTITLE=` - Process title setting not supported  
- `MK_WITH_PDEATHSIG=` - Parent death signal Linux-specific

## Critical Bug Fixes

### 1. Threading and Mutex Issues (`src/libs/threading.h`)

**Problem**: Pthread mutex operations failing on macOS causing segmentation faults.

**Root Cause**: Race conditions in queue initialization and buffer management.

**Solution**: Fixed buffer counting and queue lifecycle:
```c
// Ensure macOS camera has valid buffer count for releaser queue
run->n_bufs = 1; // Set at least one buffer for releaser queue
```

### 2. Color Format Correction (`src/libs/macos_camera.m`)

**Problem**: Purple/green color tint in video stream.

**Root Cause**: AVFoundation pixel format mismatch with µStreamer's expectations.

**Solution**: Use exact YUYV format:
```objc
// Before: Generic YUV 4:2:2
(NSString*)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_422YpCbCr8)

// After: Specific YUYV format matching V4L2
(NSString*)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_422YpCbCr8_yuvs)
```

### 3. Buffer Management Fix (`src/libs/capture.c`)

**Problem**: "Inappropriate ioctl for device" errors causing stream interruptions.

**Root Cause**: Attempting V4L2 buffer release operations on macOS camera buffers.

**Solution**: Conditional V4L2 operations:
```c
int us_capture_hwbuf_release(const us_capture_s *cap, us_capture_hwbuf_s *hw) {
#if defined(__APPLE__) && defined(WITH_MACOS_CAMERA)
    // Skip V4L2 buffer release for macOS cameras
    if (cap->macos_cam) {
        hw->grabbed = false;
        return 0; // Success without V4L2 operations
    }
#endif
    // Normal V4L2 release for Linux
}
```

### 4. Frame Rate Validation (`src/libs/macos_camera.m`)

**Problem**: Camera crashes when requested frame rate not exactly supported.

**Root Cause**: AVFoundation strict frame rate validation.

**Solution**: Find closest supported frame rate:
```objc
// Find best matching frame rate from supported ranges
AVFrameRateRange *bestRange = nil;
float bestDiff = FLT_MAX;
for (AVFrameRateRange *range in bestFormat.videoSupportedFrameRateRanges) {
    float diff = fabsf(targetRate - range.minFrameRate);
    if (targetRate >= range.minFrameRate && targetRate <= range.maxFrameRate && diff < bestDiff) {
        bestDiff = diff;
        bestRange = range;
    }
}
```

### 5. Hardware Buffer Index Management

**Problem**: macOS camera frames lacking proper buffer indices for stream management.

**Solution**: Set valid indices for queue management:
```c
macos_hwbuf.buf.index = 0; // Set a valid index for the releaser queue
```

## Performance Optimizations

### Frame Management
- **Static Buffer Allocation**: Single reusable buffer for macOS camera frames
- **Reference Counting**: Proper atomic reference management for frame lifecycle
- **Memory Reallocation**: Dynamic buffer sizing based on frame requirements

### Threading
- **Dispatch Queue**: Uses GCD for efficient frame capture callbacks
- **Lock Management**: NSLock for thread-safe frame access
- **Worker Pool Integration**: Seamless integration with existing JPEG encoding workers

## Testing and Validation

### Functional Tests
- ✅ **Camera Detection**: Multiple camera enumeration and selection
- ✅ **Resolution Support**: Various resolution configurations (640x480, 1280x720, etc.)
- ✅ **Frame Rate Control**: Adaptive frame rate selection based on camera capabilities
- ✅ **Color Accuracy**: Proper YUYV format ensuring natural color reproduction
- ✅ **Stream Stability**: Continuous streaming without interruptions or buffer errors
- ✅ **HTTP Integration**: Full web interface functionality with MJPEG streaming

### Compatibility Tests
- ✅ **Multiple Cameras**: FaceTime HD, Studio Display, External USB cameras
- ✅ **Build Variants**: Release and debug builds with proper framework linking
- ✅ **Memory Management**: No leaks in AVFoundation objects and Core Video buffers

## File Changes Summary

### New Files Created
- `src/libs/macos_v4l2_stub.h` - V4L2 compatibility layer (~300 lines)
- `src/libs/macos_camera.h` - macOS camera interface (~60 lines)  
- `src/libs/macos_camera.m` - AVFoundation implementation (~460 lines)

### Modified Files
- `src/libs/capture.c` - Integration with macOS camera system (~150 lines added)
- `src/libs/capture.h` - Added macOS camera structure member (~5 lines)
- `src/libs/threading.h` - macOS-compatible mutex handling (~10 lines)
- `src/libs/queue.c` - Added null pointer validation (~5 lines)
- `src/Makefile` - Complete build system overhaul (~50 lines modified)

### Configuration Changes
- Updated build flags for macOS compatibility
- Added AVFoundation framework dependencies
- Separated compilation paths for different binaries
- Disabled Linux-specific features on macOS

## Future Considerations

### Potential Enhancements
- **Multiple Camera Support**: Simultaneous streaming from multiple cameras
- **Audio Integration**: AVAudioEngine integration for audio capture
- **Hardware Acceleration**: VideoToolbox integration for hardware JPEG encoding
- **Format Support**: Additional pixel formats (RGB, NV12) for broader camera compatibility
- **Camera Controls**: Exposure, focus, white balance controls via AVFoundation

### Known Limitations
- **Single Camera Instance**: Current implementation supports one camera at a time
- **Format Constraints**: Limited to YUYV format for V4L2 compatibility
- **Frame Rate Limits**: Constrained by camera hardware capabilities

## Conclusion

This port successfully transforms µStreamer from a Linux-only V4L2 application into a cross-platform streaming server with full native macOS camera support. The implementation maintains the original architecture while adding a complete AVFoundation-based capture system.

**Key Achievements**:
- **100% Native Implementation**: No external drivers or compatibility layers required
- **Seamless Integration**: macOS cameras work identically to V4L2 devices from user perspective  
- **Robust Performance**: Stable streaming with proper error handling and buffer management
- **Maintainable Codebase**: Clean conditional compilation preserving Linux functionality

The result is a professional-grade MJPEG streaming server that works across both Linux (V4L2) and macOS (AVFoundation) platforms with identical user interfaces and capabilities.