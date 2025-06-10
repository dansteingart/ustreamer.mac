R_DESTDIR ?=
PREFIX ?= /usr/local

CC ?= gcc
PKG_CONFIG ?= pkg-config
CFLAGS ?= -O3
LDFLAGS ?=


# =====
_USTR = ustreamer.bin
_DUMP = ustreamer-dump.bin
_V4P = ustreamer-v4p.bin

_CFLAGS = -MD -c -std=c17 -Wall -Wextra $(CFLAGS)
ifeq ($(shell uname -s),Linux)
override _CFLAGS += -D_GNU_SOURCE
endif

# Add macOS camera support flag for ustreamer only
_USTR_CFLAGS = $(_CFLAGS)
_DUMP_CFLAGS = $(_CFLAGS)
ifeq ($(shell uname -s),Darwin)
override _USTR_CFLAGS += -DWITH_MACOS_CAMERA
endif

# macOS specific flags
ifeq ($(shell uname -s),Darwin)
override _CFLAGS += $(shell $(PKG_CONFIG) --cflags libjpeg libevent 2>/dev/null)
override _USTR_LDFLAGS += $(shell $(PKG_CONFIG) --libs libjpeg libevent libevent_pthreads 2>/dev/null)
override _DUMP_LDFLAGS += $(shell $(PKG_CONFIG) --libs libjpeg 2>/dev/null)
override _V4P_LDFLAGS += $(shell $(PKG_CONFIG) --libs libjpeg 2>/dev/null)
# Add AVFoundation and other macOS frameworks
override _USTR_LDFLAGS += -framework Foundation -framework AVFoundation -framework CoreMedia -framework CoreVideo -framework VideoToolbox -framework QuartzCore
override _DUMP_LDFLAGS += -framework Foundation
override _V4P_LDFLAGS += -framework Foundation
endif

_USTR_LDFLAGS = $(LDFLAGS) -lm -ljpeg -pthread -levent -levent_pthreads
_DUMP_LDFLAGS = $(LDFLAGS) -lm -ljpeg -pthread
_V4P_LDFLAGS = $(LDFLAGS) -lm -ljpeg -pthread

# Add -lrt only on Linux
ifeq ($(shell uname -s),Linux)
override _USTR_LDFLAGS += -lrt
override _DUMP_LDFLAGS += -lrt
override _V4P_LDFLAGS += -lrt
endif

_USTR_SRCS = $(shell ls \
	libs/*.c \
	ustreamer/*.c \
	ustreamer/http/*.c \
	ustreamer/data/*.c \
	ustreamer/encoders/cpu/*.c \
	ustreamer/encoders/hw/*.c \
	ustreamer/*.c \
)

_DUMP_SRCS = $(shell ls \
	libs/*.c \
	dump/*.c \
)

# Add macOS camera support on Darwin (only for ustreamer, not dump)
ifeq ($(shell uname -s),Darwin)
_USTR_SRCS += libs/macos_camera.m
endif

_V4P_SRCS = $(shell ls \
	libs/*.c \
	libs/drm/*.c \
	v4p/*.c \
)

_BUILD = build

_TARGETS = $(_USTR) $(_DUMP)

# Convert source files to object files (handle both .c and .m files)
# Use separate object directories to handle different compiler flags
_USTR_OBJS = $(patsubst %.c,$(_BUILD)/ustr/%.o,$(filter %.c,$(_USTR_SRCS))) $(patsubst %.m,$(_BUILD)/ustr/%.o,$(filter %.m,$(_USTR_SRCS)))
_DUMP_OBJS = $(patsubst %.c,$(_BUILD)/dump/%.o,$(filter %.c,$(_DUMP_SRCS))) $(patsubst %.m,$(_BUILD)/dump/%.o,$(filter %.m,$(_DUMP_SRCS)))
_OBJS = $(_USTR_OBJS) $(_DUMP_OBJS)


# =====
# Add atomic library only on Linux (FreeBSD and macOS don't need it)
ifeq ($(shell uname -s),Linux)
override _USTR_LDFLAGS += -latomic
override _DUMP_LDFLAGS += -latomic
override _V4P_LDFLAGS += -latomic
endif

ifneq ($(MK_WITH_PYTHON),)
override _CFLAGS += -DMK_WITH_PYTHON
endif

ifneq ($(MK_WITH_JANUS),)
override _CFLAGS += -DMK_WITH_JANUS
endif

ifneq ($(MK_WITH_GPIO),)
override _CFLAGS += -DMK_WITH_GPIO -DWITH_GPIO $(shell $(PKG_CONFIG) --atleast-version=2 libgpiod 2> /dev/null && echo -DHAVE_GPIOD2)
override _USTR_LDFLAGS += -lgpiod
override _USTR_SRCS += $(shell ls ustreamer/gpio/*.c)
endif

ifneq ($(MK_WITH_SYSTEMD),)
override _CFLAGS += -DMK_WITH_SYSTEMD -DWITH_SYSTEMD
override _USTR_LDFLAGS += -lsystemd
override _USTR_SRCS += $(shell ls ustreamer/http/systemd/*.c)
endif

ifneq ($(MK_WITH_PTHREAD_NP),)
override _CFLAGS += -DMK_WITH_PTHREAD_NP -DWITH_PTHREAD_NP
endif

ifneq ($(MK_WITH_SETPROCTITLE),)
override _CFLAGS += -DMK_WITH_SETPROCTITLE -DWITH_SETPROCTITLE
ifeq ($(shell uname -s),Linux)
override _USTR_LDFLAGS += -lbsd
endif
endif

ifneq ($(MK_WITH_PDEATHSIG),)
override _CFLAGS += -DMK_WITH_PDEATHSIG -DWITH_PDEATHSIG
endif

ifneq ($(MK_WITH_V4P),)
override _TARGETS += $(_V4P)
override _OBJS += $(_V4P_SRCS:%.c=$(_BUILD)/%.o)
override _CFLAGS += -DMK_WITH_V4P -DWITH_V4P $(shell $(PKG_CONFIG) --cflags libdrm)
override _V4P_LDFLAGS += $(shell $(PKG_CONFIG) --libs libdrm)
override _USTR_SRCS += $(shell ls libs/drm/*.c)
override _USTR_LDFLAGS += $(shell $(PKG_CONFIG) --libs libdrm)
endif


# =====
all: $(_TARGETS)


install: all
	mkdir -p $(R_DESTDIR)$(PREFIX)/bin
	for i in $(subst .bin,,$(_TARGETS)); do \
		install -m755 $$i.bin $(R_DESTDIR)$(PREFIX)/bin/$$i; \
	done


install-strip: install
	for i in $(subst .bin,,$(_TARGETS)); do \
		strip $(R_DESTDIR)$(PREFIX)/bin/$$i; \
	done


$(_USTR): $(_USTR_OBJS)
	$(info == LD $@)
	$(ECHO) $(CC) $^ -o $@ $(_USTR_LDFLAGS)


$(_DUMP): $(_DUMP_OBJS)
	$(info == LD $@)
	$(ECHO) $(CC) $^ -o $@ $(_DUMP_LDFLAGS)


$(_V4P): $(_V4P_SRCS:%.c=$(_BUILD)/%.o)
	$(info == LD $@)
	$(ECHO) $(CC) $^ -o $@ $(_V4P_LDFLAGS)


# Build rules for ustreamer objects (with macOS camera support)
$(_BUILD)/ustr/%.o: %.c
	$(info -- CC $< (ustreamer))
	$(ECHO) mkdir -p $(dir $@) || true
	$(ECHO) $(CC) $< -o $@ $(_USTR_CFLAGS)

$(_BUILD)/ustr/%.o: %.m
	$(info -- CC $< (ustreamer))
	$(ECHO) mkdir -p $(dir $@) || true
	$(ECHO) $(CC) $< -o $@ $(_USTR_CFLAGS)

# Build rules for dump objects (without macOS camera support)
$(_BUILD)/dump/%.o: %.c
	$(info -- CC $< (dump))
	$(ECHO) mkdir -p $(dir $@) || true
	$(ECHO) $(CC) $< -o $@ $(_DUMP_CFLAGS)


clean:
	rm -rf $(_USTR) $(_DUMP) $(_V4P) $(_BUILD)


-include $(_OBJS:%.o=%.d)
