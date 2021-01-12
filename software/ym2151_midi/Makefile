OPM = 10

SOURCES = \
	main.c \
	opm.c \
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

CFLAGS += -Iopm/
ARTEFACTS += opm.c opm.h

main.o: track.h opm.h

%.h %.c: %.vgm $(HEADER_GEN)
	$(HEADER_GEN) -t uint8_t -s -i $* -o $* $*.vgm

opm.h opm.c: opm/$(OPM).opm $(HEADER_GEN)
	$(HEADER_GEN) -t uint8_t -s -i opm -o opm $<

