COMMON_DIR = $(dir $(lastword $(MAKEFILE_LIST)))

include $(COMMON_DIR)/../software/common/cross.mk

SOURCES = boot.S

CFLAGS = -Wall -flto -march=rv32i -mabi=ilp32 -ffreestanding -nostdlib
DFLAGS = --line-numbers
 
ELF = boot.elf
BIN = boot.bin
HEX = boot.hex

LDS = boot.lds

$(HEX): $(BIN)
	./bin2hex.sh $(BIN) > $(HEX)
	
$(BIN): boot.elf
	$(CROSS)objcopy -O binary $(ELF) $(BIN)

dasm: boot.elf
	$(CROSS)objdump -d $(DFLAGS) $(ELF) > dasm

boot.elf: $(SOURCES)
	$(CROSS)gcc $(CFLAGS) -T $(LDS) -o $(ELF) $(SOURCES)

clean:
	rm -f $(ELF) $(BIN) $(HEX)

.PHONY: clean

