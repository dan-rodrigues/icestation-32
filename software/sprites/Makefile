# TODO: share common rules in a shared Makefile instead of repeating them here

CROSS = riscv-none-embed-
CFLAGS = -Wall -Os -flto -march=rv32i -I../lib/ -I../common/
DFLAGS = --line-numbers

LDS = ../common/sections.lds
LDS_P = sections_p.lds

SOURCES = \
	main.c \
	../common/vectors.S \
	../common/start.S \
	../lib/vdp.c \
	../common/font.c \

HEADERS = \
	../common/font.h \
	../common/font8x8_basic.h

prog.bin: prog.elf
	$(CROSS)objcopy -O binary prog.elf prog.bin

dasm: prog.elf
	$(CROSS)objdump -d $(DFLAGS) prog.elf > dasm

$(LDS_P): $(LDS)
	$(CROSS)cpp -P -o $@ $^

prog.elf: $(LDS_P) $(HEADERS) $(SOURCES)
	$(CROSS)gcc $(CFLAGS) -Wl,-Bstatic,-T,$(LDS_P),--strip-debug -ffreestanding -nostdlib -o prog.elf $(SOURCES)

clean:
	rm -f prog.elf prog.hex prog.bin
