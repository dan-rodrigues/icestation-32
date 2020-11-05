SOURCES = \
	main.c \
	../lib/audio.c \
	../lib/assert.c \
	../lib/gamepad.c \
	../lib/vdp.c \
	../common/font.c \
	../common/rand.c \

FLASH_ADPCM_SOURCES = shortbeep.c longbeep.c

HEADER_GEN_NEEDED = 1

include ../common/core.mk

main.o: shortbeep.h longbeep.h

###

%.h %.c: %.adpcm $(HEADER_GEN)
	$(HEADER_GEN) -t int16_t -s -i $* -o $* $*.adpcm
