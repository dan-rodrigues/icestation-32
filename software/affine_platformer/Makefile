SOURCES = \
	main.c \
	../lib/vdp.c \
	../lib/copper.c \
	../lib/math_util.c \
	../lib/assert.c \
	../lib/gamepad.c \
	sprite_tiles.c \
	sprite_palette.c \
	fg_tiles.c \
	fg_palette.c \
	ball_tiles.c \
	ball_palette.c \
	cloud_small_tiles.c \
	cloud_small_palette.c

GFX_CONVERT_NEEDED = 1
HEADER_GEN_NEEDED = 1

include ../common/core.mk

main.o: \
	 fg_tiles.h fg_palette.h sprite_tiles.h sprite_palette.h \
	ball_tiles.h ball_palette.h cloud_small_tiles.h cloud_small_palette.h

###

FG_GFX = fg_tiles_snes.bin
FG_PAL = fg_palette.pal

SPRITE_PNG = miyamoto.png

BALL_PNG = ball.png
CLOUD_PNG = cloud_small.png

%_tiles.bin %_palette.bin: %.png $(GFX_CONVERT)
	$(GFX_CONVERT) -f png -o $(GFX_DIR)$*_ $<

fg_tiles.bin fg_palette.bin: $(FG_GFX) $(FG_PAL) $(GFX_CONVERT)
	$(GFX_CONVERT) -f snes -p $(FG_PAL) -i 2 $(FG_GFX) -o fg_

%.c %.h: %.bin $(HEADER_GEN)
	$(HEADER_GEN) -t uint16_t -s -i $(basename $(<F)) -o $(@D)/$(*F) $<

