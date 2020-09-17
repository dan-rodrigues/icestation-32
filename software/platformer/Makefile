SOURCES = \
	main.c \
	../lib/vdp.c \
	../lib/math_util.c \
	../lib/assert.c \
	../lib/gamepad.c \
	fg_tiles.c \
	fg_palette.c \
	miyamoto_tiles.c \
	miyamoto_palette.c

GFX_CONVERT_NEEDED = 1
HEADER_GEN_NEEDED = 1

include ../common/core.mk

main.o: fg_tiles.h fg_palette.h fg_map.h miyamoto_tiles.h miyamoto_palette.h

###

FG_GFX = fg_tiles_snes.bin
FG_PAL = fg_palette.pal

SPRITE_PNG = miyamoto.png

%_tiles.bin %_palette.bin: %.png $(GFX_CONVERT)
	$(GFX_CONVERT) -f png -o $(GFX_DIR)$*_ $<

fg_tiles.bin fg_palette.bin: $(FG_GFX) $(FG_PAL) $(GFX_CONVERT)
	$(GFX_CONVERT) -f snes -p $(FG_PAL) -i 2 $(FG_GFX) -o fg_

%.c %.h: %.bin $(HEADER_GEN)
	$(HEADER_GEN) -t uint16_t -s -i $(basename $(<F)) -o $(@D)/$(*F) $<

