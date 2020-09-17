SOURCES = \
	main.c \
	../common/font.c \
	../common/tinyprintf.c \
	../lib/vdp.c \
	../lib/audio.c \
	../lib/vdp_print.c \
	../lib/assert.c \
	../lib/gamepad.c

FLASH_ADPCM_SOURCES = snare.c kick.c cymbal.c

HEADER_GEN_NEEDED = 1

include ../common/core.mk

main.o: snare.h kick.h cymbal.h

###

%.h %.c: %.adpcm $(HEADER_GEN)
	$(HEADER_GEN) -t int16_t -s -i $* -o $* $*.adpcm

