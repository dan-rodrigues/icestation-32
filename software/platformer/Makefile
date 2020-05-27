SOURCES = \
	main.c \
	../common/vectors.S \
	../common/start.S \
	../lib/vdp.c \
	../lib/math_util.c \
	../lib/assert.c \
	../common/font.c \
	map-flat.c

HEADERS = \
	../lib/vdp.h \
	../lib/math_util.h \
	../lib/assert.h \
	fg_tiles.h \
	fg_palette.h \
	map-flat.h \
	sprite_tiles.h \
	sprite_palette.h

include ../common/common.mk

FG_GFX = GFX15.bin
FG_PAL = redrawn-palette.pal

SPRITE_PNG = miyamoto.png

PNG_CONVERTER_DIR = ../../utilities/png_convert/
PNG_CONVERTER = $(PNG_CONVERTER_DIR)ics-png-convert

$(PNG_CONVERTER):
	$(MAKE) -C $(PNG_CONVERTER_DIR)

#tiles.h palette.h: $(PNG) $(PNG_CONVERTER)
#	$(PNG_CONVERTER) -f png $(PNG)

fg_tiles.h fg_palette.h: $(FG_GFX) $(FG_PAL) $(PNG_CONVERTER)
	$(PNG_CONVERTER) -f snes -p $(FG_PAL) -i 2 $(FG_GFX) -o fg_

sprite_tiles.h sprite_palette.h: $(SPRITE_PNG) $(PNG_CONVERTER)
	$(PNG_CONVERTER) -f png $(SPRITE_PNG) -o sprite_

