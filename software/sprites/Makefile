# TODO: share common rules in a shared Makefile instead of repeating them here

CROSS = riscv-none-embed-
CFLAGS = -Wall -Os -flto -march=rv32i -I../lib/ -I../common/ -ffreestanding -nostdlib
DFLAGS = --line-numbers

LDS = ../common/sections.lds
LDS_P = sections_p.lds

SOURCES = \
	main.c \
	../common/vectors.S \
	../common/start.S \
	../lib/vdp.c \
	../lib/math_util.c \
	../common/font.c \

HEADERS = \
	../common/font.h \
	../common/font8x8_basic.h \
	tiles.h \
	palette.h

prog.bin: prog.elf
	$(CROSS)objcopy -O binary prog.elf prog.bin

PNG_CONVERTER = ../../utilities/gfx_convert/ics-png-convert

$(PNG_CONVERTER):
	$(MAKE) -C ../../utilities/gfx_convert

tiles.h palette.h: crystal-32-ia.png $(PNG_CONVERTER)
	$(PNG_CONVERTER) crystal-32-ia.png

dasm: prog.elf
	$(CROSS)objdump -d $(DFLAGS) prog.elf > dasm

$(LDS_P): $(LDS)
	$(CROSS)cpp -P -o $@ $^

prog.elf: $(LDS_P) $(HEADERS) $(SOURCES)
	$(CROSS)gcc $(CFLAGS) -Wl,-Bstatic,-T,$(LDS_P),--strip-debug -o prog.elf $(SOURCES)

clean:
	rm -f prog.elf prog.hex prog.bin
