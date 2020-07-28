# Options:

# If set, a boot prompt is displayed before loading user program from flash
BOOT_PROMPT = 0

###

FW_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
SW_DIR := $(FW_DIR)/../software/

include $(FW_DIR)/../software/common/cross.mk

SW_SOURCES := $(addprefix $(SW_DIR), \
	common/font.c \
	lib/vdp.c \
	lib/assert.c \
)

HEADERS := $($(SW_SOURCES):%.c=%.h)

SOURCES := boot.S bootprint.c $(SW_SOURCES)

CFLAGS = -Wall -flto -march=rv32i -mabi=ilp32 -Os -ffreestanding -nostdlib \
	-DBOOT_PROMPT=$(BOOT_PROMPT) \
	-I$(SW_DIR)lib/ -I$(SW_DIR)common/

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

boot.elf: $(SOURCES) $(HEADERS)
	$(CROSS)gcc $(CFLAGS) -T $(LDS) -o $(ELF) $(SOURCES)

clean:
	rm -f $(ELF) $(BIN) $(HEX)

.PHONY: clean

