/*****************************************************************************
#                                                                            #
#    uStreamer - Lightweight and fast MJPEG-HTTP streamer.                   #
#                                                                            #
#    macOS V4L2 stub - minimal definitions to allow compilation              #
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

#pragma once

#ifdef __APPLE__

#include <stdint.h>
#include <sys/time.h>

// Basic V4L2 type definitions - stubs for macOS compilation
typedef uint32_t __u32;
typedef uint16_t __u16;
typedef uint8_t __u8;
typedef int32_t __s32;
typedef int64_t __s64;
typedef uint64_t __u64;
typedef uint64_t v4l2_std_id;

// V4L2 enums
enum v4l2_buf_type {
    V4L2_BUF_TYPE_VIDEO_CAPTURE        = 1,
    V4L2_BUF_TYPE_VIDEO_OUTPUT         = 2,
    V4L2_BUF_TYPE_VIDEO_OVERLAY        = 3,
    V4L2_BUF_TYPE_VBI_CAPTURE          = 4,
    V4L2_BUF_TYPE_VBI_OUTPUT           = 5,
    V4L2_BUF_TYPE_SLICED_VBI_CAPTURE   = 6,
    V4L2_BUF_TYPE_SLICED_VBI_OUTPUT    = 7,
    V4L2_BUF_TYPE_VIDEO_OUTPUT_OVERLAY = 8,
    V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE = 9,
    V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE  = 10,
    V4L2_BUF_TYPE_SDR_CAPTURE          = 11,
    V4L2_BUF_TYPE_SDR_OUTPUT           = 12,
    V4L2_BUF_TYPE_META_CAPTURE         = 13,
    V4L2_BUF_TYPE_META_OUTPUT          = 14,
    V4L2_BUF_TYPE_PRIVATE              = 0x80,
};

enum v4l2_memory {
    V4L2_MEMORY_MMAP    = 1,
    V4L2_MEMORY_USERPTR = 2,
    V4L2_MEMORY_OVERLAY = 3,
    V4L2_MEMORY_DMABUF  = 4,
};

// V4L2 constants - pixel formats
#define V4L2_PIX_FMT_YUYV     0x56595559  /* 16  YUV 4:2:2     */
#define V4L2_PIX_FMT_UYVY     0x59565955  /* 16  YUV 4:2:2     */
#define V4L2_PIX_FMT_YVYU     0x55595659  /* 16  YVU 4:2:2     */
#define V4L2_PIX_FMT_YUV420   0x32315659  /* 12  YUV 4:2:0     */
#define V4L2_PIX_FMT_YVU420   0x32315960  /* 12  YVU 4:2:0     */
#define V4L2_PIX_FMT_RGB24    0x00424752  /* 24  RGB-8-8-8     */
#define V4L2_PIX_FMT_BGR24    0x00524742  /* 24  BGR-8-8-8     */
#define V4L2_PIX_FMT_RGB565   0x00474252  /* 16  RGB-5-6-5     */
#define V4L2_PIX_FMT_GREY     0x59455247  /*  8  Greyscale     */
#define V4L2_PIX_FMT_MJPEG    0x47504A4D  /* Motion-JPEG       */
#define V4L2_PIX_FMT_JPEG     0x4745504A  /* JFIF JPEG         */
#define V4L2_PIX_FMT_H264     0x34363248  /* H.264             */

// V4L2 video standards
#define V4L2_STD_UNKNOWN      0x00000000ULL
#define V4L2_STD_PAL          0x000000ffULL
#define V4L2_STD_NTSC         0x0000b000ULL
#define V4L2_STD_SECAM        0x00ff0000ULL

// Additional constants
#define VIDEO_MAX_PLANES      8
#define V4L2_DV_BT_656_1120   0

// Events
#define V4L2_EVENT_SOURCE_CHANGE  5
#define V4L2_EVENT_EOS           2

// Capabilities
#define V4L2_CAP_VIDEO_CAPTURE_MPLANE  0x00001000

#define V4L2_FIELD_NONE         1
#define V4L2_FIELD_INTERLACED   4
#define V4L2_FIELD_ANY          0

#define V4L2_COLORSPACE_SRGB    1
#define V4L2_COLORSPACE_REC709  1
#define V4L2_COLORSPACE_JPEG    7
#define V4L2_COLORSPACE_DEFAULT 0

// V4L2 structures - minimal stubs
struct v4l2_capability {
    __u8    driver[16];
    __u8    card[32];
    __u8    bus_info[32];
    __u32   version;
    __u32   capabilities;
    __u32   device_caps;
    __u32   reserved[3];
};

struct v4l2_pix_format {
    __u32           width;
    __u32           height;
    __u32           pixelformat;
    __u32           field;
    __u32           bytesperline;
    __u32           sizeimage;
    __u32           colorspace;
    __u32           priv;
    __u32           flags;
    __u32           ycbcr_enc;
    __u32           quantization;
    __u32           xfer_func;
};

struct v4l2_pix_format_mplane {
    __u32               width;
    __u32               height;
    __u32               pixelformat;
    __u32               field;
    __u32               colorspace;
    struct v4l2_plane_pix_format {
        __u32           sizeimage;
        __u32           bytesperline;
        __u16           reserved[6];
    } plane_fmt[8];
    __u8                num_planes;
    __u8                flags;
    union {
        __u8    ycbcr_enc;
        __u8    hsv_enc;
    };
    __u8                quantization;
    __u8                xfer_func;
    __u8                reserved[7];
};

struct v4l2_format {
    __u32    type;
    union {
        struct v4l2_pix_format          pix;
        struct v4l2_pix_format_mplane   pix_mp;
        __u8                            raw_data[200];
    } fmt;
};

struct v4l2_timecode {
    __u32   type;
    __u32   flags;
    __u8    frames;
    __u8    seconds;
    __u8    minutes;
    __u8    hours;
    __u8    userbits[4];
};

struct v4l2_plane {
    __u32           bytesused;
    __u32           length;
    union {
        __u32           mem_offset;
        unsigned long   userptr;
        __s32           fd;
    } m;
    __u32           data_offset;
    __u32           reserved[11];
};

struct v4l2_buffer {
    __u32           index;
    __u32           type;
    __u32           bytesused;
    __u32           flags;
    __u32           field;
    struct timeval  timestamp;
    struct v4l2_timecode timecode;
    __u32           sequence;
    __u32           memory;
    union {
        __u32           offset;
        unsigned long   userptr;
        struct v4l2_plane *planes;
        __s32           fd;
    } m;
    __u32           length;
    __u32           reserved2;
    __u32           reserved;
};

struct v4l2_requestbuffers {
    __u32           count;
    __u32           type;
    __u32           memory;
    __u32           reserved[2];
};

struct v4l2_streamparm {
    __u32    type;
    union {
        struct {
            __u32              capability;
            __u32              capturemode;
            struct {
                __u32   numerator;
                __u32   denominator;
            } timeperframe;
            __u32              extendedmode;
            __u32              readbuffers;
            __u32              reserved[4];
        } capture;
        struct {
            __u32              capability;
            __u32              outputmode;
            struct {
                __u32   numerator;
                __u32   denominator;
            } timeperframe;
            __u32              extendedmode;
            __u32              writebuffers;
            __u32              reserved[4];
        } output;
        __u8    raw_data[200];
    } parm;
};

struct v4l2_control {
    __u32           id;
    __s32           value;
};

struct v4l2_queryctrl {
    __u32           id;
    __u32           type;
    __u8            name[32];
    __s32           minimum;
    __s32           maximum;
    __s32           step;
    __s32           default_value;
    __u32           flags;
    __u32           reserved[2];
};

struct v4l2_event {
    __u32                   type;
    union {
        __u8    data[64];
    } u;
    __u32                   pending;
    __u32                   sequence;
    struct {
        __s64   tv_sec;
        __s64   tv_nsec;
    } timestamp;
    __u32                   id;
    __u32                   reserved[8];
};

struct v4l2_event_subscription {
    __u32                   type;
    __u32                   id;
    __u32                   flags;
    __u32                   reserved[5];
};

struct v4l2_jpegcompression {
    int quality;
    int APPn;
    int APP_len;
    char APP_data[60];
    int COM_len;
    char COM_data[60];
    __u32 jpeg_markers;
};

struct v4l2_exportbuffer {
    __u32   type;
    __u32   index;
    __u32   plane;
    __u32   flags;
    __s32   fd;
    __u32   reserved[11];
};

struct v4l2_dv_timings {
    __u32   type;
    union {
        struct {
            __u32   width;
            __u32   height;
            __u32   interlaced;
            __u32   polarities;
            __u64   pixelclock;
            __u32   hfrontporch;
            __u32   hsync;
            __u32   hbackporch;
            __u32   vfrontporch;
            __u32   vsync;
            __u32   vbackporch;
            __u32   il_vfrontporch;
            __u32   il_vsync;
            __u32   il_vbackporch;
            __u32   standards;
            __u32   flags;
            __u32   reserved[14];
        } bt;
        __u32   reserved[32];
    };
};

// V4L2 ioctl definitions - all will fail on macOS
#define VIDIOC_QUERYCAP           0x80685600
#define VIDIOC_G_FMT              0xc0d05604
#define VIDIOC_S_FMT              0xc0d05605
#define VIDIOC_REQBUFS            0xc0145608
#define VIDIOC_QUERYBUF           0xc0585609
#define VIDIOC_QBUF               0xc058560f
#define VIDIOC_DQBUF              0xc0585611
#define VIDIOC_STREAMON           0x40045612
#define VIDIOC_STREAMOFF          0x40045613
#define VIDIOC_G_PARM             0xc0cc5615
#define VIDIOC_S_PARM             0xc0cc5616
#define VIDIOC_G_CTRL             0xc008561b
#define VIDIOC_S_CTRL             0xc008561c
#define VIDIOC_QUERYCTRL          0xc0445624
#define VIDIOC_S_INPUT            0xc0045626
#define VIDIOC_S_STD              0x40085618
#define VIDIOC_QUERYSTD           0x8008563f
#define VIDIOC_QUERY_DV_TIMINGS   0x80845663
#define VIDIOC_S_DV_TIMINGS       0xc0845657
#define VIDIOC_DQEVENT            0x80885659
#define VIDIOC_SUBSCRIBE_EVENT    0x40205652
#define VIDIOC_G_JPEGCOMP         0x808c563d
#define VIDIOC_S_JPEGCOMP         0x408c563e
#define VIDIOC_EXPBUF             0xc0405610

// Additional constants used in the codebase
#define V4L2_CAP_VIDEO_CAPTURE          0x00000001
#define V4L2_CAP_STREAMING              0x04000000
#define V4L2_CAP_TIMEPERFRAME           0x00001000
#define V4L2_BUF_FLAG_MAPPED            0x00000001
#define V4L2_BUF_FLAG_QUEUED            0x00000002
#define V4L2_BUF_FLAG_DONE              0x00000004
#define V4L2_BUF_FLAG_KEYFRAME          0x00000008
#define V4L2_CTRL_FLAG_DISABLED         0x00000001

// Control IDs commonly used
#define V4L2_CID_BASE                   0x00980900
#define V4L2_CID_USER_BASE              0x00980000
#define V4L2_CID_BRIGHTNESS             (V4L2_CID_BASE+0)
#define V4L2_CID_CONTRAST               (V4L2_CID_BASE+1)
#define V4L2_CID_SATURATION             (V4L2_CID_BASE+2)
#define V4L2_CID_HUE                    (V4L2_CID_BASE+3)
#define V4L2_CID_DV_RX_POWER_PRESENT    (V4L2_CID_BASE+100)
#define V4L2_CID_AUTOBRIGHTNESS         (V4L2_CID_BASE+4)
#define V4L2_CID_HUE_AUTO               (V4L2_CID_BASE+25)
#define V4L2_CID_GAMMA                  (V4L2_CID_BASE+16)
#define V4L2_CID_SHARPNESS              (V4L2_CID_BASE+27)
#define V4L2_CID_BACKLIGHT_COMPENSATION (V4L2_CID_BASE+28)
#define V4L2_CID_AUTO_WHITE_BALANCE     (V4L2_CID_BASE+12)
#define V4L2_CID_WHITE_BALANCE_TEMPERATURE (V4L2_CID_BASE+26)
#define V4L2_CID_AUTOGAIN               (V4L2_CID_BASE+18)
#define V4L2_CID_GAIN                   (V4L2_CID_BASE+19)
#define V4L2_CID_COLORFX                (V4L2_CID_BASE+31)
#define V4L2_CID_ROTATE                 (V4L2_CID_BASE+34)
#define V4L2_CID_VFLIP                  (V4L2_CID_BASE+20)
#define V4L2_CID_HFLIP                  (V4L2_CID_BASE+21)

// Additional control constants that may be needed
#define V4L2_CID_CAMERA_CLASS_BASE      0x009A0900
#define V4L2_CID_CAMERA_CLASS           (V4L2_CID_CAMERA_CLASS_BASE + 0)
#define V4L2_CID_EXPOSURE_AUTO          (V4L2_CID_CAMERA_CLASS_BASE + 1)
#define V4L2_CID_EXPOSURE_ABSOLUTE      (V4L2_CID_CAMERA_CLASS_BASE + 2)
#define V4L2_CID_FOCUS_AUTO             (V4L2_CID_CAMERA_CLASS_BASE + 12)
#define V4L2_CID_FOCUS_ABSOLUTE         (V4L2_CID_CAMERA_CLASS_BASE + 10)

// MPEG video controls
#define V4L2_CID_MPEG_BASE              0x00990900
#define V4L2_CID_MPEG_VIDEO_BITRATE     (V4L2_CID_MPEG_BASE + 200)
#define V4L2_CID_MPEG_VIDEO_H264_I_PERIOD (V4L2_CID_MPEG_BASE + 300)
#define V4L2_CID_MPEG_VIDEO_H264_PROFILE (V4L2_CID_MPEG_BASE + 301)
#define V4L2_CID_MPEG_VIDEO_H264_LEVEL  (V4L2_CID_MPEG_BASE + 302)
#define V4L2_CID_MPEG_VIDEO_REPEAT_SEQ_HEADER (V4L2_CID_MPEG_BASE + 250)
#define V4L2_CID_MPEG_VIDEO_H264_MIN_QP (V4L2_CID_MPEG_BASE + 303)
#define V4L2_CID_MPEG_VIDEO_H264_MAX_QP (V4L2_CID_MPEG_BASE + 304)
#define V4L2_CID_MPEG_VIDEO_FORCE_KEY_FRAME (V4L2_CID_MPEG_BASE + 305)
#define V4L2_CID_JPEG_COMPRESSION_QUALITY (V4L2_CID_MPEG_BASE + 500)

// H.264 profile and level constants
#define V4L2_MPEG_VIDEO_H264_PROFILE_CONSTRAINED_BASELINE 1
#define V4L2_MPEG_VIDEO_H264_LEVEL_4_0  4
#define V4L2_MPEG_VIDEO_H264_LEVEL_5_1  5

// DV timing constants (often used in capture hardware)
#define V4L2_DV_BT_STD_CEA861           (1 << 0)
#define V4L2_DV_BT_STD_DMT              (1 << 1)
#define V4L2_DV_BT_STD_CVT              (1 << 2)
#define V4L2_DV_BT_STD_GTF              (1 << 3)

// Helper macros for DV timing calculations
#define V4L2_DV_BT_FRAME_WIDTH(bt) \
    ((bt)->width + (bt)->hfrontporch + (bt)->hsync + (bt)->hbackporch)
#define V4L2_DV_BT_FRAME_HEIGHT(bt) \
    ((bt)->height + (bt)->vfrontporch + (bt)->vsync + (bt)->vbackporch)

#endif /* __APPLE__ */