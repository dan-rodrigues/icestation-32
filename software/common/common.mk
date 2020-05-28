COMMON_DIR = $(dir $(lastword $(MAKEFILE_LIST)))

CROSS = riscv-none-embed-
CFLAGS = -Wall -Os -flto -march=rv32i -I$(COMMON_DIR) -I$(COMMON_DIR)../lib/ -I./ -ffreestanding -nostdlib
DFLAGS = --line-numbers
 
LDS = ../common/sections.lds
LDS_P = sections_p.lds

BIN = prog.bin

$(BIN): prog.elf
	$(CROSS)objcopy -O binary prog.elf prog.bin

dasm: prog.elf
	$(CROSS)objdump -d $(DFLAGS) prog.elf > dasm

$(LDS_P): $(LDS)
	$(CROSS)cpp -P -o $@ $^

prog.elf: $(LDS_P) $(HEADERS) $(SOURCES)
	$(CROSS)gcc $(CFLAGS) -Wl,-Bstatic,-T,$(LDS_P),--strip-debug -o prog.elf $(SOURCES)

clean:
	rm -f prog.elf prog.hex $(BIN)

.PHONY: clean
