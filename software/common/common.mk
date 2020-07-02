COMMON_DIR = $(dir $(lastword $(MAKEFILE_LIST)))
include $(COMMON_DIR)/cross.mk

SIM_DIR = $(COMMON_DIR)../../simulator/

ifeq ($(OPT_LEVEL),)
OPT_LEVEL := -Os
endif

CFLAGS = -Wall $(OPT_LEVEL) -flto -march=rv32i -mabi=ilp32 -I$(COMMON_DIR) -I$(COMMON_DIR)../lib/ -I./ -ffreestanding -nostdlib
DFLAGS = --line-numbers
 
LDS = ../common/sections.lds
LDS_P = sections_p.lds

BIN = prog.bin

$(BIN): prog.elf
	$(CROSS)objcopy -O binary prog.elf $(BIN)

dasm: prog.elf
	$(CROSS)objdump -d $(DFLAGS) prog.elf > dasm

$(LDS_P): $(LDS)
	$(CROSS)cpp -P -o $@ $^

prog.elf: $(LDS_P) $(HEADERS) $(SOURCES)
	$(CROSS)gcc $(CFLAGS) -Wl,-Bstatic,-T,$(LDS_P),--strip-debug -o prog.elf $(SOURCES) -lgcc

clean:
	rm -f prog.elf prog.hex $(BIN)

sim: $(BIN)
	set -e ;\
	make -C $(SIM_DIR) verilator_sim ;\
	$(SIM_DIR)verilator_sim $(BIN) ;

.PHONY: clean sim
