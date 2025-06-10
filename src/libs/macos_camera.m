/*****************************************************************************
#                                                                            #
#    uStreamer - Lightweight and fast MJPEG-HTTP streamer.                   #
#                                                                            #
#    macOS Camera Support - AVFoundation implementation                      #
#                                                                            #
#    Copyright (C) 2018-2024  Maxim Devaev <mdevaev@gmail.com>               #
#                                                                            #
#    This program is free software: you can redistribute it and/or modify    #
#    it under the terms of the GNU General Public License as published by    #
#    the Free Software Foundation, either version 3 of the License, or       #
#    (at your option) any later version.                                     #
#                                                                            #
#    This program is distributed in the hope that it will be useful,         #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of          #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           #
#    GNU General Public License for more details.                            #
#                                                                            #
#    You should have received a copy of the GNU General Public License       #
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.  #
#                                                                            #
*****************************************************************************/

#ifdef __APPLE__

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <VideoToolbox/VideoToolbox.h>
#import <QuartzCore/QuartzCore.h>
#include <math.h>
#include <float.h>
#include <sys/time.h>

#include "macos_camera.h"
#include "tools.h"
#include "logging.h"
#include "macos_v4l2_stub.h"

@interface MacOSCameraDelegate : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, strong) NSLock *frameLock;
@property (nonatomic, strong) NSCondition *frameCondition;
@property (nonatomic) CVPixelBufferRef latestFrame;
@property (nonatomic) bool hasNewFrame;
@property (nonatomic) uint64_t frameCount;
@property (nonatomic) uint64_t droppedFrames;
@property (nonatomic) double lastFrameTime;
@property (nonatomic) double targetFrameInterval;
@end

@implementation MacOSCameraDelegate

- (instancetype)init {
    self = [super init];
    if (self) {
        _frameLock = [[NSLock alloc] init];
        _frameCondition = [[NSCondition alloc] init];
        _latestFrame = NULL;
        _hasNewFrame = false;
        _frameCount = 0;
        _droppedFrames = 0;
        _lastFrameTime = 0.0;
        _targetFrameInterval = 1.0/30.0; // Default 30fps
    }
    return self;
}

- (void)dealloc {
    [_frameLock lock];
    if (_latestFrame) {
        CVPixelBufferRelease(_latestFrame);
        _latestFrame = NULL;
    }
    [_frameLock unlock];
    [super dealloc];
}

- (void)captureOutput:(AVCaptureOutput *)output 
    didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
           fromConnection:(AVCaptureConnection *)connection {
    
    @autoreleasepool {
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        if (!pixelBuffer) return;
        
        // Frame rate throttling - drop frames if coming too fast
        double currentTime = CACurrentMediaTime();
        if (_lastFrameTime > 0 && (currentTime - _lastFrameTime) < _targetFrameInterval) {
            _droppedFrames++;
            return; // Drop this frame
        }
        
        // Try to acquire lock without blocking - drop frame if busy
        if (![_frameLock tryLock]) {
            _droppedFrames++;
            return;
        }
        
        // Drop frame if previous hasn't been consumed yet, but allow some through for snapshots
        if (_hasNewFrame) {
            // Allow every 10th frame through even if previous hasn't been consumed 
            // This ensures snapshots can work while still preventing buffer buildup
            if (_frameCount % 10 != 0) {
                _droppedFrames++;
                [_frameLock unlock];
                return;
            }
            // Force release the old frame to make room for the new one
            if (_latestFrame) {
                CVPixelBufferRelease(_latestFrame);
                _latestFrame = NULL;
            }
        }
        
        // Release previous frame
        if (_latestFrame) {
            CVPixelBufferRelease(_latestFrame);
            _latestFrame = NULL;
        }
        
        // Retain new frame
        _latestFrame = CVPixelBufferRetain(pixelBuffer);
        _hasNewFrame = true;
        _frameCount++;
        _lastFrameTime = currentTime;
        
        [_frameLock unlock];
        
        // Signal waiting threads that a new frame is available
        [_frameCondition lock];
        [_frameCondition signal];
        [_frameCondition unlock];
    }
}

@end

struct macos_camera_s {
    AVCaptureSession *session;
    AVCaptureDevice *device;
    AVCaptureDeviceInput *input;
    AVCaptureVideoDataOutput *output;
    MacOSCameraDelegate *delegate;
    dispatch_queue_t queue;
    
    // Configuration
    uint width;
    uint height;
    uint fps;
    uint format;
    
    // State
    bool running;
    char *device_name;
};

// Logging macros for this module
#define _LOG_ERROR(x_msg, ...)   US_LOG_ERROR("MACOS_CAM: " x_msg, ##__VA_ARGS__)
#define _LOG_INFO(x_msg, ...)    US_LOG_INFO("MACOS_CAM: " x_msg, ##__VA_ARGS__)
#define _LOG_VERBOSE(x_msg, ...) US_LOG_VERBOSE("MACOS_CAM: " x_msg, ##__VA_ARGS__)
#define _LOG_DEBUG(x_msg, ...)   US_LOG_DEBUG("MACOS_CAM: " x_msg, ##__VA_ARGS__)

macos_camera_s *macos_camera_init(void) {
    macos_camera_s *cam;
    US_CALLOC(cam, 1);
    
    @autoreleasepool {
        cam->session = [[AVCaptureSession alloc] init];
        cam->delegate = [[MacOSCameraDelegate alloc] init];
        // Use concurrent queue with QOS_CLASS_USER_INITIATED for better memory management
        dispatch_queue_attr_t queueAttr = dispatch_queue_attr_make_with_qos_class(
            DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0);
        cam->queue = dispatch_queue_create("ustreamer.camera.queue", queueAttr);
        
        // Set default values
        cam->width = 640;
        cam->height = 480;
        cam->fps = 30;
        cam->format = V4L2_PIX_FMT_YUYV;
        cam->running = false;
        cam->device_name = NULL;
    }
    
    _LOG_INFO("Initialized macOS camera interface");
    return cam;
}

void macos_camera_destroy(macos_camera_s *cam) {
    if (cam == NULL) return;
    
    @autoreleasepool {
        if (cam->running) {
            macos_camera_stop(cam);
        }
        
        if (cam->device_name) {
            free(cam->device_name);
        }
        
        if (cam->queue) {
            dispatch_release(cam->queue);
        }
    }
    
    free(cam);
    _LOG_INFO("Destroyed macOS camera interface");
}

int macos_camera_list_devices(void) {
    @autoreleasepool {
        _LOG_INFO("Available cameras:");
        
        AVCaptureDeviceDiscoverySession *discoverySession = [AVCaptureDeviceDiscoverySession
            discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera,
                                               AVCaptureDeviceTypeExternal]
                                  mediaType:AVMediaTypeVideo
                                   position:AVCaptureDevicePositionUnspecified];
        
        NSArray<AVCaptureDevice *> *devices = discoverySession.devices;
        
        for (NSUInteger i = 0; i < devices.count; i++) {
            AVCaptureDevice *device = devices[i];
            _LOG_INFO("  %lu: %s (%s)", (unsigned long)i, 
                     device.localizedName.UTF8String ?: "Unknown",
                     device.uniqueID.UTF8String ?: "no-id");
        }
        
        return (int)devices.count;
    }
}

int macos_camera_select_device(macos_camera_s *cam, const char *device_id) {
    if (cam == NULL) return -1;
    
    @autoreleasepool {
        AVCaptureDevice *selectedDevice = nil;
        
        if (device_id && strcmp(device_id, "/dev/video0") != 0) {
            // Try to find device by ID or index
            AVCaptureDeviceDiscoverySession *discoverySession = [AVCaptureDeviceDiscoverySession
                discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera,
                                                   AVCaptureDeviceTypeExternal]
                                      mediaType:AVMediaTypeVideo
                                       position:AVCaptureDevicePositionUnspecified];
            
            NSArray<AVCaptureDevice *> *devices = discoverySession.devices;
            
            // Try to parse as index first
            char *endptr;
            long indexLong = strtol(device_id, &endptr, 10);
            if (*endptr == '\0' && indexLong >= 0 && (NSUInteger)indexLong < devices.count) {
                int index = (int)indexLong;
                selectedDevice = devices[index];
            } else {
                // Try to find by unique ID
                NSString *targetID = [NSString stringWithUTF8String:device_id];
                for (AVCaptureDevice *device in devices) {
                    if ([device.uniqueID isEqualToString:targetID]) {
                        selectedDevice = device;
                        break;
                    }
                }
            }
        }
        
        // Fall back to default device
        if (selectedDevice == nil) {
            selectedDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        }
        
        if (selectedDevice == nil) {
            _LOG_ERROR("No camera devices found");
            return -1;
        }
        
        cam->device = selectedDevice;
        
        // Store device name
        if (cam->device_name) {
            free(cam->device_name);
        }
        const char *name = selectedDevice.localizedName.UTF8String ?: "Unknown Camera";
        cam->device_name = us_strdup(name);
        
        _LOG_INFO("Selected camera: %s (%s)", name, selectedDevice.uniqueID.UTF8String ?: "no-id");
        return 0;
    }
}

int macos_camera_set_resolution(macos_camera_s *cam, uint width, uint height) {
    if (cam == NULL) return -1;
    
    cam->width = width;
    cam->height = height;
    
    _LOG_INFO("Set resolution: %ux%u", width, height);
    return 0;
}

int macos_camera_set_fps(macos_camera_s *cam, uint fps) {
    if (cam == NULL) return -1;
    
    cam->fps = fps;
    if (cam->delegate) {
        cam->delegate.targetFrameInterval = 1.0 / (double)fps;
    }
    _LOG_INFO("Set FPS: %u", fps);
    return 0;
}

int macos_camera_set_format(macos_camera_s *cam, uint format) {
    if (cam == NULL) return -1;
    
    cam->format = format;
    _LOG_INFO("Set format: 0x%08X", format);
    return 0;
}

int macos_camera_start(macos_camera_s *cam) {
    if (cam == NULL || cam->device == NULL) return -1;
    if (cam->running) return 0;
    
    @autoreleasepool {
        NSError *error = nil;
        
        // Create input
        cam->input = [AVCaptureDeviceInput deviceInputWithDevice:cam->device error:&error];
        if (error || !cam->input) {
            _LOG_ERROR("Failed to create device input: %s", 
                      error.localizedDescription.UTF8String ?: "unknown error");
            return -1;
        }
        
        // Create output with performance optimizations
        cam->output = [[AVCaptureVideoDataOutput alloc] init];
        cam->output.alwaysDiscardsLateVideoFrames = YES; // Critical for performance
        
        // Set video settings - use YUYV format which matches V4L2 YUYV exactly
        NSDictionary *videoSettings = @{
            (NSString*)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_422YpCbCr8_yuvs), // YUYV format
            (NSString*)kCVPixelBufferWidthKey: @(cam->width),
            (NSString*)kCVPixelBufferHeightKey: @(cam->height)
        };
        cam->output.videoSettings = videoSettings;
        
        // Set delegate
        [cam->output setSampleBufferDelegate:cam->delegate queue:cam->queue];
        
        // Configure session with minimal memory footprint
        [cam->session beginConfiguration];
        
        // Use low-memory session preset to prevent buffer pool bloat
        if ([cam->session canSetSessionPreset:AVCaptureSessionPresetLow]) {
            cam->session.sessionPreset = AVCaptureSessionPresetLow;
        } else if ([cam->session canSetSessionPreset:AVCaptureSessionPresetMedium]) {
            cam->session.sessionPreset = AVCaptureSessionPresetMedium;
        }
        
        if ([cam->session canAddInput:cam->input]) {
            [cam->session addInput:cam->input];
        } else {
            _LOG_ERROR("Cannot add camera input to session");
            [cam->session commitConfiguration];
            return -1;
        }
        
        if ([cam->session canAddOutput:cam->output]) {
            [cam->session addOutput:cam->output];
        } else {
            _LOG_ERROR("Cannot add camera output to session");
            [cam->session commitConfiguration];
            return -1;
        }
        
        // Try to set desired resolution and frame rate
        AVCaptureConnection *connection = [cam->output connectionWithMediaType:AVMediaTypeVideo];
        if (connection) {
            // Find best format
            AVCaptureDeviceFormat *bestFormat = nil;
            for (AVCaptureDeviceFormat *format in cam->device.formats) {
                CMVideoDimensions dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
                if ((uint)dims.width == cam->width && (uint)dims.height == cam->height) {
                    bestFormat = format;
                    break;
                }
            }
            
            if (bestFormat) {
                if ([cam->device lockForConfiguration:&error]) {
                    cam->device.activeFormat = bestFormat;
                    
                    // Set frame rate - find closest supported rate
                    AVFrameRateRange *bestRange = nil;
                    float bestDiff = FLT_MAX;
                    
                    for (AVFrameRateRange *range in bestFormat.videoSupportedFrameRateRanges) {
                        float minRate = range.minFrameRate;
                        float maxRate = range.maxFrameRate;
                        float targetRate = (float)cam->fps;
                        
                        if (targetRate >= minRate && targetRate <= maxRate) {
                            float diff = fabsf(targetRate - minRate);
                            if (diff < bestDiff) {
                                bestDiff = diff;
                                bestRange = range;
                            }
                        }
                    }
                    
                    if (bestRange) {
                        // Set frame rate - prefer target fps if in range, otherwise use minimum
                        float actualFps = (float)cam->fps;
                        if (actualFps < bestRange.minFrameRate) {
                            actualFps = bestRange.minFrameRate;
                        } else if (actualFps > bestRange.maxFrameRate) {
                            actualFps = bestRange.maxFrameRate;
                        }
                        
                        CMTime frameDuration = CMTimeMake(1000000, (int)(actualFps * 1000000));
                        cam->device.activeVideoMinFrameDuration = frameDuration;
                        cam->device.activeVideoMaxFrameDuration = frameDuration;
                        
                        // Update delegate's target frame interval
                        cam->delegate.targetFrameInterval = 1.0 / actualFps;
                        
                        _LOG_INFO("Applied format: %dx%d @%.1ffps (adjusted)", 
                                 (int)cam->width, (int)cam->height, actualFps);
                    } else {
                        _LOG_ERROR("No compatible frame rate found for %dfps", (int)cam->fps);
                    }
                    
                    [cam->device unlockForConfiguration];
                } else {
                    _LOG_ERROR("Failed to lock device for configuration: %s",
                              error.localizedDescription.UTF8String ?: "unknown error");
                }
            }
        }
        
        [cam->session commitConfiguration];
        
        // Start session
        [cam->session startRunning];
        cam->running = true;
        
        _LOG_INFO("Camera started successfully");
        return 0;
    }
}

int macos_camera_stop(macos_camera_s *cam) {
    if (cam == NULL || !cam->running) return 0;
    
    @autoreleasepool {
        [cam->session stopRunning];
        
        // Wait a bit for session to fully stop
        usleep(100000); // 100ms
        
        [cam->session removeInput:cam->input];
        [cam->session removeOutput:cam->output];
        
        // Clear delegate to break potential retention cycles
        [cam->output setSampleBufferDelegate:nil queue:nil];
        
        // Ensure final frame is released
        [cam->delegate.frameLock lock];
        if (cam->delegate.latestFrame) {
            CVPixelBufferRelease(cam->delegate.latestFrame);
            cam->delegate.latestFrame = NULL;
        }
        cam->delegate.hasNewFrame = false;
        [cam->delegate.frameLock unlock];
        
        cam->input = nil;
        cam->output = nil;
        cam->running = false;
        
        _LOG_INFO("Camera stopped");
        return 0;
    }
}

int macos_camera_has_frame(macos_camera_s *cam) {
    if (cam == NULL || cam->delegate == NULL) return 0;
    
    [cam->delegate.frameLock lock];
    bool hasFrame = cam->delegate.hasNewFrame;
    [cam->delegate.frameLock unlock];
    
    return hasFrame ? 1 : 0;
}

int macos_camera_wait_frame(macos_camera_s *cam, double timeout_sec) {
    if (cam == NULL || cam->delegate == NULL) return -1;
    
    [cam->delegate.frameCondition lock];
    
    // Check if frame is already available
    if (macos_camera_has_frame(cam)) {
        [cam->delegate.frameCondition unlock];
        return 1;
    }
    
    // Calculate absolute timeout
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:timeout_sec];
    
    // Wait for frame with timeout
    BOOL success = [cam->delegate.frameCondition waitUntilDate:timeoutDate];
    [cam->delegate.frameCondition unlock];
    
    if (success && macos_camera_has_frame(cam)) {
        return 1; // Frame available
    } else {
        return 0; // Timeout or no frame
    }
}

static int _pixel_buffer_to_frame(CVPixelBufferRef pixelBuffer, us_frame_s *frame, uint target_format) {
    if (!pixelBuffer || !frame) return -1;
    
    CVReturn result = CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    if (result != kCVReturnSuccess) {
        return -1;
    }
    
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
    void *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
    
    if (!baseAddress) {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
        return -1;
    }
    
    // Calculate required buffer size
    size_t dataSize = bytesPerRow * height;
    
    // Safety check: prevent runaway memory allocation
    if (dataSize > 50 * 1024 * 1024) { // 50MB limit per frame
        _LOG_ERROR("Frame size too large: %zu bytes (%zux%zu, stride=%zu)", 
                  dataSize, width, height, bytesPerRow);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
        return -1;
    }
    
    // Ensure frame buffer is large enough
    us_frame_realloc_data(frame, dataSize);
    
    // Copy pixel data efficiently
    memcpy(frame->data, baseAddress, dataSize);
    frame->used = dataSize;
    frame->width = (uint)width;
    frame->height = (uint)height;
    frame->format = target_format;
    frame->stride = (uint)bytesPerRow;
    
    // Set timestamp and online status
    frame->grab_ts = us_get_now_monotonic();
    frame->encode_begin_ts = 0;
    frame->encode_end_ts = 0;
    frame->online = true; // Mark frame as live/online
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    return 0;
}

int macos_camera_grab_frame(macos_camera_s *cam, us_frame_s *frame) {
    if (cam == NULL || cam->delegate == NULL || frame == NULL) return -1;
    
    [cam->delegate.frameLock lock];
    
    if (!cam->delegate.hasNewFrame || !cam->delegate.latestFrame) {
        [cam->delegate.frameLock unlock];
        return -1; // No new frame available
    }
    
    // Convert pixel buffer to frame
    int result = _pixel_buffer_to_frame(cam->delegate.latestFrame, frame, cam->format);
    
    // Mark frame as consumed and log memory stats periodically
    cam->delegate.hasNewFrame = false;
    
    // Log memory usage every 300 frames (10 seconds at 30fps)
    if (cam->delegate.frameCount % 300 == 0) {
        _LOG_DEBUG("Memory stats: frame=%zu bytes, total_frames=%llu, dropped=%llu",
                  frame->used, cam->delegate.frameCount, cam->delegate.droppedFrames);
    }
    
    [cam->delegate.frameLock unlock];
    
    return result;
}

const char *macos_camera_get_name(macos_camera_s *cam) {
    return (cam && cam->device_name) ? cam->device_name : "Unknown Camera";
}

int macos_camera_get_width(macos_camera_s *cam) {
    return cam ? (int)cam->width : 0;
}

int macos_camera_get_height(macos_camera_s *cam) {
    return cam ? (int)cam->height : 0;
}

int macos_camera_get_fps(macos_camera_s *cam) {
    return cam ? (int)cam->fps : 0;
}

// Add performance monitoring functions
int macos_camera_get_dropped_frames(macos_camera_s *cam) {
    if (!cam || !cam->delegate) return 0;
    return (int)cam->delegate.droppedFrames;
}

int macos_camera_get_total_frames(macos_camera_s *cam) {
    if (!cam || !cam->delegate) return 0;
    return (int)cam->delegate.frameCount;
}

double macos_camera_get_drop_rate(macos_camera_s *cam) {
    if (!cam || !cam->delegate) return 0.0;
    uint64_t total = cam->delegate.frameCount + cam->delegate.droppedFrames;
    return total > 0 ? (double)cam->delegate.droppedFrames / (double)total : 0.0;
}

#endif // __APPLE__