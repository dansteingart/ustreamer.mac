/*****************************************************************************
#                                                                            #
#    uStreamer - Lightweight and fast MJPEG-HTTP streamer.                   #
#                                                                            #
#    macOS Camera Support - AVFoundation interface                           #
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

#include "types.h"
#include "frame.h"

// Forward declarations for Objective-C types
typedef struct macos_camera_s macos_camera_s;

// Camera management functions
macos_camera_s *macos_camera_init(void);
void macos_camera_destroy(macos_camera_s *cam);

// Camera discovery and selection
int macos_camera_list_devices(void);
int macos_camera_select_device(macos_camera_s *cam, const char *device_id);

// Camera configuration
int macos_camera_set_resolution(macos_camera_s *cam, uint width, uint height);
int macos_camera_set_fps(macos_camera_s *cam, uint fps);
int macos_camera_set_format(macos_camera_s *cam, uint format);

// Camera control
int macos_camera_start(macos_camera_s *cam);
int macos_camera_stop(macos_camera_s *cam);

// Frame capture
int macos_camera_grab_frame(macos_camera_s *cam, us_frame_s *frame);
int macos_camera_has_frame(macos_camera_s *cam);
int macos_camera_wait_frame(macos_camera_s *cam, double timeout_sec);

// Camera information
const char *macos_camera_get_name(macos_camera_s *cam);
int macos_camera_get_width(macos_camera_s *cam);
int macos_camera_get_height(macos_camera_s *cam);
int macos_camera_get_fps(macos_camera_s *cam);

// Performance monitoring
int macos_camera_get_dropped_frames(macos_camera_s *cam);
int macos_camera_get_total_frames(macos_camera_s *cam);
double macos_camera_get_drop_rate(macos_camera_s *cam);

#endif // __APPLE__