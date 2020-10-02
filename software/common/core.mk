### Options:

# Enables assertions (lib/assert.h)
ASSERT_ENABLED ?= 1

# Builds the given utility if set to 1
GFX_CONVERT_NEEDED ?= 0
HEADER_GEN_NEEDED ?= 0
SIN_GEN_NEEDED ?= 0

MK_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
include $(MK_DIR)cross.mk

UTIL_DIR := $(MK_DIR)../../utilities/
SIM_DIR := $(MK_DIR)../../simulator/

### Building shared utility dependencies

GFX_CONVERT_DIR := $(UTIL_DIR)gfx_convert/
GFX_CONVERT := $(GFX_CONVERT_DIR)gfx_convert

HEADER_GEN_DIR := $(UTIL_DIR)header_gen/
HEADER_GEN := $(HEADER_GEN_DIR)header_gen

# Old versions of make need the outer eval() to prevent false missing-separator errors

define build_util
$(eval
	$(if $(findstring 1, $1),
		$(info Building $3 if needed)
		$(if $(filter-out 0,$(shell $(MAKE) -C $2 > $3_log 2>&1; echo $$?)),
			$(info test me $3_log)
			$(info $(shell cat $3_log))
			$(error Failed to build $3)
		)
	)
)
endef

$(call build_util,$(GFX_CONVERT_NEEDED),$(GFX_CONVERT_DIR),gfx_convert)
$(call build_util,$(HEADER_GEN_NEEDED),$(HEADER_GEN_DIR),header_gen)

###

ASM := $(addprefix $(MK_DIR), \
	vectors.S \
	start.S \
	)

ifeq ($(OPT_LEVEL),)
OPT_LEVEL := -Os
endif

CFLAGS := \
	-std=c11 \
	-Wall $(OPT_LEVEL) -MMD -MP -flto -march=rv32i -mabi=ilp32 \
	-I$(MK_DIR)../common/ -I$(MK_DIR)../lib/ -I./ \
	-ffreestanding -nostdlib

### Assertion enabling

include $(MK_DIR)utility.mk

ASSERT_ENABLED_FLAG_PATH := $(abspath $(MK_DIR)ASSERT_ENABLED)
$(eval $(call persisted_var_path,ASSERT_ENABLED,$(ASSERT_ENABLED_FLAG_PATH)))

ifeq ($(ASSERT_ENABLED), 1)
CFLAGS += -DASSERT_ENABLED
RC_CFLAGS += -DASSERT_ENABLED
endif

$(abspath $(MK_DIR)../lib/assert.o): $(ASSERT_ENABLED_FLAG_PATH)

###

LIB_SOURCES := $(addprefix $(MK_DIR)../lib/, $(LIB_SOURCES))
SOURCES += $(foreach source, $(LIB_SOURCES), $(abspath $(source)))

RC_CFLAGS += \
	-std=c11 \
	-Wall $(OPT_LEVEL) -MMD -MP -march=rv32i -mabi=ilp32 \
	-I$(MK_DIR)../common -I$(MK_DIR)../lib \
	-ffreestanding -nostdlib
	
DFLAGS = --line-numbers
 
LDS = $(MK_DIR)sections.lds
LDS_P = sections_p.lds

BIN = prog.bin
ELF = prog.elf

ASM_OBJ := $(ASM:%.S=%.o)
SOURCES_OBJ := $(SOURCES:%.c=%.o)

### Rule definition for flash assets:

# Since only 1 stem can be defined, this works around that limitation using foreach

define flash_dep
$1$3$2.o: $1$2.c
# No -flto option on these
# Linker errors such as section overflows appear otherwise
	$(CROSS)gcc $$(RC_CFLAGS) -c $$< -o $$@
endef

define flash_obj
$(foreach source, $1, $(dir $(source))$2$(basename $(notdir $(source))).o) 
endef

define flash_dep_all
$(foreach source, $1, $(eval $(call flash_dep,$(dir $(source)),$(basename $(notdir $(source))),$2)))
endef

FLASH_CPU_OBJ := $(call flash_obj,$(FLASH_CPU_SOURCES),flash_cpu_)
$(call flash_dep_all,$(FLASH_CPU_SOURCES),flash_cpu_)

FLASH_ADPCM_OBJ := $(call flash_obj,$(FLASH_ADPCM_SOURCES),flash_adpcm_)
$(call flash_dep_all,$(FLASH_ADPCM_SOURCES),flash_adpcm_)

### Autodeps:

ALL_SOURCES := $(SOURCES)
ALL_OBJ := $(SOURCES_OBJ) $(FLASH_CPU_OBJ) $(FLASH_ADPCM_OBJ) $(ASM_OBJ)
DEP := $(ALL_OBJ:.o=.d)
-include $(DEP)

### Core rules:

$(BIN): $(ELF)
	$(CROSS)objcopy -O binary $(ELF) $(BIN)

dasm: $(ELF)
	$(CROSS)objdump -d $(DFLAGS) $(ELF) > dasm

$(LDS_P): $(LDS)
	$(CROSS)cpp -P -o $@ $^

$(ELF): $(LDS_P) $(ALL_OBJ)
	$(CROSS)gcc $(CFLAGS) -Wl,-Bstatic,-T,$(LDS_P),--strip-debug $(ALL_OBJ) -o $@ -lgcc

%.o: %.c
	$(CROSS)gcc $(CFLAGS) -c $< -o $@

%.o: %.S
	$(CROSS)gcc $(CFLAGS) -c $< -o $@

clean:
	rm -f $(ELF) $(BIN) $(ALL_OBJ) $(DEP) $(ARTEFACTS)

### Phony helper targets

sim: $(BIN)
	set -e ;\
	make -C $(SIM_DIR) verilator_sim ;\
	cd $(SIM_DIR) ;\
	./verilator_sim $(abspath $(BIN));

ulx3s_prog: $(BIN)
	fujprog -j flash -f 0x200000 $(BIN)

icebreaker_prog: $(BIN)
	iceprog -o 2M $(BIN)

.DEFAULT_GOAL := $(BIN)
.PHONY: clean sim ulx3s_prog icebreaker_prog
.SECONDARY:
