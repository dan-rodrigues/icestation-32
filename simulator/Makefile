BOOT_DIR = ../firmware
BOOT_HEX = $(BOOT_DIR)/boot.hex

main-build: pre-build
	@$(MAKE) --no-print-directory cxxrtl_sim

pre-build:
	@$(MAKE) -C $(BOOT_DIR)

###

### common ###

SIM_IMPL = CXXRTLSimulation
SIM_SRCS = main.cpp $(SIM_IMPL).cpp

### cxxrtl ###

CXXRTL_INCLUDES := $(shell yosys-config --datdir/include)
CXX_OPT = -O3
CXXRTL_CFLAGS := \
	$(shell sdl2-config --cflags) \
	-DSIM_CXXRTL \
	-DCXXRTL_INCLUDE_VCD_CAPI_IMPL

CXXRTL_OPT = -O6

ifeq ($(TRACE), 1)
	CXXRTL_CFLAGS += -DCXXRTL_INCLUDE_VCD_CAPI_IMPL -DVCD_WRITE
	CXXRTL_OPT = -Og
endif

CXXRTL_LDFLAGS := $(shell sdl2-config --libs)
CXXRTL_HDL_DEFINES = -DVERILATOR -DEXTERNAL_CLOCKS -DDEBUGNETS -DALPHA_LUT="alpha_lut.hex"

include ../hardware/sources.mk

HDL_TOP = ics32_tb
HDL_DIR = ../hardware
HDL_SOURCES := $(SOURCES:%.v=$(HDL_DIR)/%.v)
HDL_SOURCES += $(HDL_TOP).v cells_sim.v sim_spiflash.v

cxxrtl_sim: cxxrtl_sim.cpp
	g++ -std=c++14 $(CXX_OPT) -I$(CXXRTL_INCLUDES) cxxrtl_sim.cpp $(SIM_SRCS) $(CXXRTL_CFLAGS) $(CXXRTL_LDFLAGS) -o $@

cxxrtl_sim.cpp: $(HDL_SOURCES) $(BOOT_HEX) alpha_lut.hex
	yosys -p \
		'verilog_defines -DBOOTLOADER="$(BOOT_HEX)" $(CXXRTL_HDL_DEFINES); \
		read_verilog -I$(HDL_DIR) $(HDL_SOURCES); \
		hierarchy -check -top $(HDL_TOP); \
		proc; flatten; clean; splitnets -driver; clean -purge; \
		write_cxxrtl -header $(CXXRTL_OPT) $@'

# remove cxxrtl_sim.cpp as phony target when this is all working
.PHONY: main-build # cxxrtl_sim.cpp

### Verilator ###

verilator_sim:
	./build.sh

.PHONY: verilator_sim

