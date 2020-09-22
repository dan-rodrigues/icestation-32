# Options:

# If set, a boot prompt is displayed before loading user program from flash
BOOT_PROMPT ?= 0

###

FW_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
SW_DIR := $(FW_DIR)../software/

include $(FW_DIR)../software/common/cross.mk

SW_SOURCES := $(addprefix $(SW_DIR), \
	common/font.c \
	lib/vdp.c \
	lib/assert.c \
)

SW_HEADERS := $($(SW_SOURCES):%.c=%.h)

FW_SOURCES := $(addprefix $(FW_DIR),\
	boot.S \
	bootprint.c \
	)

FW_CFLAGS := -Wall -flto -march=rv32i -mabi=ilp32 -Os -ffreestanding -nostdlib \
	-DBOOT_PROMPT=$(BOOT_PROMPT) \
	-I$(SW_DIR)lib/ -I$(SW_DIR)common/

FW_DFLAGS := --line-numbers

FW_HEX_CONVERT := $(FW_DIR)bin2hex.sh

BOOT_ELF := $(FW_DIR)boot.elf
BOOT_BIN := $(FW_DIR)boot.bin
BOOT_HEX := $(FW_DIR)boot.hex

BOOT_LDS := $(FW_DIR)boot.lds

$(BOOT_HEX): $(BOOT_BIN)
	$(FW_HEX_CONVERT) $(BOOT_BIN) > $(BOOT_HEX)
	
$(BOOT_BIN): $(BOOT_ELF)
	$(CROSS)objcopy -O binary $(BOOT_ELF) $(BOOT_BIN)

$(BOOT_ELF): $(FW_SOURCES) $(SW_SOURCES) $(SW_HEADERS)
	$(CROSS)gcc $(FW_CFLAGS) -T $(BOOT_LDS) -o $(BOOT_ELF) $(FW_SOURCES)
	
boot_dasm: $(BOOT_ELF)
	$(CROSS)objdump -d $(FW_DFLAGS) $(BOOT_ELF) > $@

boot_clean:
	rm -f $(BOOT_ELF) $(BOOT_BIN) $(BOOT_HEX)

.PHONY: boot_clean
