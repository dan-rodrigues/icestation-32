SOURCES = \
	main.c \
	../common/font.c \
	../common/tinyprintf.c \
	../common/vectors.S \
	../common/start.S \
	../lib/vdp.c \
	../lib/audio.c \
	../lib/vdp_print.c \
	../lib/assert.c \
	../lib/gamepad.c

HEADERS = \
	../common/font.h \
	../common/tinyprintf.h \
	../lib/vdp.h \
	../lib/audio.h \
	../lib/vdp_print.h \
	../lib/assert.h \
	../lib/gamepad.h

RC_SOURCES = snare.c kick.c cymbal.c

include ../common/common.mk

HEADER_GEN_DIR = ../../utilities/header_gen
HEADER_GEN := $(HEADER_GEN_DIR)/header_gen

# Ensure utility dependencies are up to date

pre-build:
	@$(MAKE) -C $(HEADER_GEN_DIR)

main-build: pre-build
	@$(MAKE) --no-print-directory $(BIN)

.PHONY: main-build

.DEFAULT_GOAL := main-build

###

%.h %.c: %.adpcm $(HEADER_GEN)
	$(HEADER_GEN) -t int16_t -s -i $* -o $* $*.adpcm

