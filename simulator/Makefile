# Include rules needed to build the boot firmware

include ../firmware/boot.mk

BOOT_HEX_SELECTED := $(BOOT_MULTI_HEX)

### Common ###

SIM_SRCS = main.cpp Simulation.cpp QSPIFlashSim.cpp tinywav/tinywav.cpp
SIM_HEADERS =  Simulation.hpp

HDL_TOP = ics32_tb
HDL_DIR = ../hardware

# This must be set if ics32_tb.ENABLE_BOOTLOADER is also set
# The Pico has parameters for the reset vector but the Vex doesn't
# (This should be made a build-time-configurable top level param)
VEX_USE_BOOTLOADER = 1
include ../hardware/sources.mk

HDL_SOURCES := $(SOURCES:%.v=$(HDL_DIR)/%.v)
HDL_SOURCES += $(HDL_TOP).v $(HDL_DIR)/common/spram_256k.v

CXX_OPT = -O3

### CXXRTL ###

CXXRTL_OPT = -O6
cxxrtl_sim_trace: CXXRTL_OPT = -Og

CXXRTL_SRCS = CXXRTLSimulation.cpp
CXXRTL_HEADERS = $(CXXRTL_SRCS:%.cpp=%.hpp)
CXXRTL_INCLUDES := $(shell yosys-config --datdir/include)
CXXRTL_CFLAGS := \
	-Wall \
	-Itinywav/ \
	$(shell sdl2-config --cflags) \
	-DSIM_CXXRTL \
	-DCXXRTL_INCLUDE_CAPI_IMPL

cxxrtl_sim_trace: CXXRTL_CFLAGS += -DCXXRTL_INCLUDE_VCD_CAPI_IMPL -DVCD_WRITE=1

CXXRTL_LDFLAGS := $(shell sdl2-config --libs)
CXXRTL_HDL_DEFINES = -DSIMULATOR -DEXTERNAL_CLOCKS -DDEBUGNETS -DALPHA_LUT="alpha_lut.hex"

define write-cxxrtl-sim
	yosys -p \
		'verilog_defines -DBOOTLOADER="$(BOOT_HEX_SELECTED)" $(CXXRTL_HDL_DEFINES); \
		read_verilog -I$(HDL_DIR) $(CXXRTL_SIM_MODELS) $(HDL_SOURCES); \
		hierarchy -check -top $(HDL_TOP); \
		proc; flatten; clean; splitnets -driver; clean -purge; \
		write_cxxrtl -header $(CXXRTL_OPT) $@'
endef

define build-sim
	g++ -std=c++14 $(CXX_OPT) -I$(CXXRTL_INCLUDES) $(CXXRTL_CFLAGS) $< $(SIM_SRCS) $(CXXRTL_SRCS) $(CXXRTL_LDFLAGS) -o $@

endef

cxxrtl_sim: cxxrtl_sim.cpp $(SIM_SRCS) $(CXXRTL_SRCS) $(CXXRTL_HEADERS) $(SIM_HEADERS)
	$(build-sim)

cxxrtl_sim_trace: cxxrtl_sim_trace.cpp $(SIM_SRCS) $(CXXRTL_SRCS) $(CXXRTL_HEADERS) $(SIM_HEADERS)	
	$(build-sim)

CXXRTL_DEPS = $(HDL_SOURCES) $(BOOT_HEX) $(CXXRTL_SIM_MODELS) alpha_lut.hex
 
cxxrtl_sim.cpp: $(CXXRTL_DEPS)
	$(write-cxxrtl-sim)

cxxrtl_sim_trace.cpp: $(CXXRTL_DEPS)
	$(write-cxxrtl-sim)

### Verilator ###

VLT_SIM_NAME = ics32-sim

VLT_FLAGS =	\
	-cc --language 1364-2005 -v config.vlt -O3 --assert \
	-Wall -Wno-fatal -Wno-WIDTH -Wno-TIMESCALEMOD \
	-I$(HDL_DIR) \
	-DBOOTLOADER=\"$(BOOT_HEX_SELECTED)\" -DEXTERNAL_CLOCKS -DSIMULATOR

VLT_CXX_SOURCES = $(SIM_SRCS) ../VerilatorSimulation.cpp
VLT_CFLAGS := -std=c++14 $(CXX_OPT) $(shell sdl2-config --cflags) -I../ -I../tinywav/ -DSIM_VERILATOR
VLT_LDFLAGS := $(shell sdl2-config --libs)

verilator_sim_trace: VLT_CFLAGS += -DVCD_WRITE=1
verilator_sim_trace: VLT_FLAGS += --trace

# Verilator already manages dependencies, generates its own Makefile, forwards your C/LDFLAGS etc.
# There is no need to duplicate that effort here, just invokve it everytime and it'll only do
# work if necessary.

define build-verilator-sim
	set -e ;\
	verilator $(VLT_FLAGS) -o $(VLT_SIM_NAME) \
		--top-module $(HDL_TOP) $(HDL_SOURCES) \
		-CFLAGS "$(VLT_CFLAGS)" -LDFLAGS "$(VLT_LDFLAGS)" --exe $(VLT_CXX_SOURCES) ;\
	make -C obj_dir/ -f V$(HDL_TOP).mk ;\
	cp obj_dir/$(VLT_SIM_NAME) $@
endef

verilator_sim: $(BOOT_HEX_SELECTED)
	$(build-verilator-sim)

verilator_sim_trace: $(BOOT_HEX_SELECTED)
	$(build-verilator-sim)

.PHONY: verilator_sim verilator_sim_trace

.DEFAULT_GOAL = verilator_sim

