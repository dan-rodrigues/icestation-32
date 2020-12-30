SOURCES = \
	main.c \
	../common/font.c \
	../common/tinyprintf.c \
	../lib/vdp.c \
	../lib/ym2151.c \
	../lib/vdp_print.c \
	../lib/assert.c \
	../lib/gamepad.c \

HEADER_GEN_NEEDED = 1

FLASH_CPU_SOURCES = track.c

include ../common/core.mk

main.o: track.h

%.h %.c: %.vgm $(HEADER_GEN)
	$(HEADER_GEN) -t uint8_t -s -i $* -o $* $*.vgm

