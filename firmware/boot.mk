# Options:

# If set, a boot prompt is displayed before loading user program from flash
BOOT_PROMPT ?= 0

# QPI is disabled by default due to certain issues with the official iceprog
QPI_MODE ?= 0

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

FW_SOURCES := $(addprefix $(FW_DIR), \
	boot.S \
	bootprint.c \
	winbond_configure.S \
	)

FW_MULTI_SOURCES := $(addprefix $(FW_DIR), \
	issi_configure.S \
	flash_detect.S \
	)

FW_INCLUDES := $(addprefix $(FW_DIR), \
	boot_defines.S \
	)

FW_MULTI_CFLAGS := -Wall -flto -march=rv32i -mabi=ilp32 -Os -ffreestanding -nostdlib \
	-I$(SW_DIR)lib/ -I$(SW_DIR)common/

ifeq ($(BOOT_PROMPT), 1)
FW_MULTI_CFLAGS += -DBOOT_PROMPT
endif

ifeq ($(QPI_MODE), 1)
FW_MULTI_CFLAGS += -DQPI_MODE
endif

FW_CFLAGS := $(FW_MULTI_CFLAGS) -DASSUME_WINBOND

FW_DFLAGS := --line-numbers

FW_HEX_CONVERT := $(FW_DIR)bin2hex.sh

BOOT_ELF := $(FW_DIR)boot.elf
BOOT_BIN := $(FW_DIR)boot.bin
BOOT_HEX := $(FW_DIR)boot.hex

BOOT_MULTI_ELF := $(FW_DIR)boot_multi.elf
BOOT_MULTI_BIN := $(FW_DIR)boot_multi.bin
BOOT_MULTI_HEX := $(FW_DIR)boot_multi.hex

BOOT_LDS := $(FW_DIR)boot.lds

%.hex: %.bin
	$(FW_HEX_CONVERT) $< > $@
	
%.bin: %.elf
	$(CROSS)objcopy -O binary $< $@

$(BOOT_ELF): $(FW_SOURCES) $(SW_SOURCES) $(SW_HEADERS) $(FW_DIR)boot_defines.S
	$(CROSS)gcc $(FW_CFLAGS) -T $(BOOT_LDS) -o $@ $(FW_SOURCES) $(SW_SOURCES)

$(BOOT_MULTI_ELF): $(FW_SOURCES) $(FW_MULTI_SOURCES) $(SW_SOURCES) $(SW_HEADERS) $(FW_INCLUDES)
	$(CROSS)gcc $(FW_MULTI_CFLAGS) -T $(BOOT_LDS) -o $@ $(FW_SOURCES) $(FW_MULTI_SOURCES) $(SW_SOURCES)

boot_dasm: $(BOOT_ELF)
	$(CROSS)objdump -d $(FW_DFLAGS) $(BOOT_ELF) > $@

boot_clean:
	rm -f \
	$(BOOT_ELF) $(BOOT_BIN) $(BOOT_HEX) \
	$(BOOT_MULTI_ELF) $(BOOT_MULTI_BIN) $(BOOT_MULTI_HEX)

.PHONY: boot_clean
.SECONDARY: $(BOOT_BIN) $(BOOT_MULTI_BIN)

