CROSS = riscv-none-embed-

SOURCES = boot.S

COMMON_DIR = $(dir $(lastword $(MAKEFILE_LIST)))

OPT_LEVEL := -Os

CFLAGS = -Wall $(OPT_LEVEL) -flto -march=rv32i -I$(COMMON_DIR) -I$(COMMON_DIR)../lib/ -I./ -ffreestanding -nostdlib
DFLAGS = --line-numbers
 
BIN = boot.bin
LDS = boot.lds

$(BIN): boot.elf
	$(CROSS)objcopy -O binary boot.elf $(BIN)

dasm: boot.elf
	$(CROSS)objdump -d $(DFLAGS) boot.elf > dasm

boot.elf: $(HEADERS) $(SOURCES)
	$(CROSS)gcc $(CFLAGS) -T $(LDS) -o boot.elf $(SOURCES) -lgcc

clean:
	rm -f boot.elf boot.hex $(BIN)

.PHONY: clean sim

