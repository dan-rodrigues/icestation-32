BOOT_DIR = ../firmware/
BOOT_HEX = $(BOOT_DIR)boot.hex

main-build: pre-build
	@$(MAKE) --no-print-directory cxxrtl_sim

pre-build:
	@$(MAKE) -C $(BOOT_DIR)

###

CXX_OPT = -O3

CXXRTL_SRCS = cxxrtl/main.cpp

CXXRTL_CFLAGS := $(shell sdl2-config --cflags) -DSIM_INCLUDE=\"../cxxrtl_sim.cpp\" # !!!
CXXRTL_OPT = -O6

ifeq ($(TRACE), 1)
	CXXRTL_CFLAGS += -DCXXRTL_INCLUDE_VCD_CAPI_IMPL -DVCD_WRITE
	CXXRTL_OPT = -Og
endif

CXXRTL_LDFLAGS := $(shell sdl2-config --libs)
CXXRTL_OPT = -O3
CXXRTL_INCLUDES := $(shell yosys-config --datdir/include)!
CXXRTL_HDL_DEFINES = -DVERILATOR -DEXTERNAL_CLOCKS -DDEBUGNETS -DALPHA_LUT="alpha_lut.hex"

include ../hardware/sources.mk

HDL_TOP = ics32_tb
HDL_DIR = ../hardware
HDL_SOURCES := $(SOURCES:%.v=$(HDL_DIR)/%.v)
HDL_SOURCES += $(HDL_TOP).v cells_sim.v sim_spiflash.v

cxxrtl_sim: cxxrtl_sim.cpp $(CXXRTL_SRCS)
	g++ -std=c++14 $(CXX_OPT) -I$(CXXRTL_INCLUDES) $(CXXRTL_SRCS) $(CXXRTL_CFLAGS) $(CXXRTL_LDFLAGS) -o $@

cxxrtl_sim.cpp: $(HDL_SOURCES) $(BOOT_HEX) alpha_lut.hex
	yosys -p \
		'verilog_defines -DBOOTLOADER="$(BOOT_HEX)" $(CXXRTL_HDL_DEFINES); \
		read_verilog -I$(HDL_DIR) $(HDL_SOURCES); \
		hierarchy -check -top $(HDL_TOP); \
		proc; flatten; clean; splitnets -driver; clean -purge; \
		write_cxxrtl -header $(CXXRTL_OPT) $@'

# remove cxxrtl_sim.cpp as phony target when this is all working
.PHONY: main-build cxxrtl_sim # cxxrtl_sim.cpp
