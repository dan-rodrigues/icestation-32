SOURCES = \
	main.c \
	crystal_tiles.c \
	crystal_palette.c \
	../lib/vdp.c \
	../lib/math_util.c \
	../common/font.c

GFX_CONVERT_NEEDED = 1
HEADER_GEN_NEEDED = 1

include ../common/core.mk

###

PNG = crystal.png

main.o: crystal_tiles.h crystal_palette.h

%_tiles.bin %_palette.bin: %.png $(GFX_CONVERT)
	$(GFX_CONVERT) -f png -o $*_ $<

%.c %.h: %.bin $(HEADER_GEN)
	$(HEADER_GEN) -t uint16_t -s -i $(basename $(<F)) -o $(@D)/$(*F) $<

