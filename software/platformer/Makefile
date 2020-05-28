SOURCES = \
	main.c \
	../common/vectors.S \
	../common/start.S \
	../lib/vdp.c \
	../lib/math_util.c \
	../lib/assert.c \
	../lib/gamepad.c

HEADERS = \
	../lib/vdp.h \
	../lib/math_util.h \
	../lib/assert.h \
	../lib/gamepad.h \
	fg_tiles.h \
	fg_palette.h \
	fg_map.h \
	sprite_tiles.h \
	sprite_palette.h

include ../common/common.mk

# Ensure utility dependencies are up to date

pre-build:
	@$(MAKE) -C $(PNG_CONVERTER_DIR)

main-build: pre-build
	@$(MAKE) --no-print-directory $(BIN)

.PHONY: main-build

.DEFAULT_GOAL := main-build

###

FG_GFX = fg_tiles.bin
FG_PAL = fg_palette.pal

SPRITE_PNG = miyamoto.png

PNG_CONVERTER_DIR = ../../utilities/png_convert/
PNG_CONVERTER = $(PNG_CONVERTER_DIR)ics-png-convert

$(PNG_CONVERTER):
	$(MAKE) -C $(PNG_CONVERTER_DIR)

fg_tiles.h fg_palette.h: $(FG_GFX) $(FG_PAL) $(PNG_CONVERTER)
	$(PNG_CONVERTER) -f snes -p $(FG_PAL) -i 2 $(FG_GFX) -o fg_

sprite_tiles.h sprite_palette.h: $(SPRITE_PNG) $(PNG_CONVERTER)
	$(PNG_CONVERTER) -f png $(SPRITE_PNG) -o sprite_
