# Ensure bootloader file is up to date

BOOT_DIR = ../firmware
BOOT_HEX = $(BOOT_DIR)/boot.hex

.PHONY: dummy
dummy:
	@$(MAKE) -C $(BOOT_DIR)

-include dummy

### Common ###

SIM_NAME = ics32-sim
SIM_SRCS = main.cpp
SIM_HEADERS =  Simulation.hpp

HDL_TOP = ics32_tb
HDL_DIR = ../hardware

include ../hardware/sources.mk

HDL_SOURCES := $(SOURCES:%.v=$(HDL_DIR)/%.v)
HDL_SOURCES += $(HDL_TOP).v cells_sim.v sim_spiflash.v

CXX_OPT = -O3

### CXXRTL ###

CXXRTL_OPT = -O6
cxxrtl_sim_trace: CXXRTL_OPT = -Og

CXXRTL_SRCS = CXXRTLSimulation.cpp
CXXRTL_INCLUDES := $(shell yosys-config --datdir/include)
CXXRTL_CFLAGS := \
	-Wall \
	$(shell sdl2-config --cflags) \
	-DSIM_CXXRTL \
	-DCXXRTL_INCLUDE_CAPI_IMPL

cxxrtl_sim_trace: CXXRTL_CFLAGS += -DCXXRTL_INCLUDE_VCD_CAPI_IMPL -DVCD_WRITE=1

CXXRTL_LDFLAGS := $(shell sdl2-config --libs)
CXXRTL_HDL_DEFINES = -DVERILATOR -DEXTERNAL_CLOCKS -DDEBUGNETS -DALPHA_LUT="alpha_lut.hex"

define write-sim
	yosys -p \
		'verilog_defines -DBOOTLOADER="$(BOOT_HEX)" $(CXXRTL_HDL_DEFINES); \
		read_verilog -I$(HDL_DIR) $(HDL_SOURCES); \
		hierarchy -check -top $(HDL_TOP); \
		proc; flatten; clean; splitnets -driver; clean -purge; \
		write_cxxrtl -header $(CXXRTL_OPT) $@'
endef

define build-sim
	g++ -std=c++14 $(CXX_OPT) -I$(CXXRTL_INCLUDES) $(CXXRTL_CFLAGS) $(CXXRTL_LDFLAGS) $< $(SIM_SRCS) $(CXXRTL_SRCS) -o $@
endef

cxxrtl_sim: cxxrtl_sim.cpp $(SIM_SRCS) $(CXXRTL_SRCS) $(SIM_HEADERS)
	$(build-sim)

cxxrtl_sim_trace: cxxrtl_sim_trace.cpp $(SIM_SRCS) $(CXXRTL_SRCS) $(SIM_HEADERS)	
	$(build-sim)

$(CXXRTL_DEPS): $(HDL_SOURCES) $(BOOT_HEX) alpha_lut.hex
 
cxxrtl_sim.cpp: $(CXXRTL_DEPS)
	$(write-sim)

cxxrtl_sim_trace.cpp: $(CXXRTL_DEPS)
	$(write-sim)

.PHONY: main-build

### Verilator ###

VLT_FLAGS =	\
	-cc --language 1364-2005 -v config.vlt -O3 --assert \
	-Wall -Wno-fatal -Wno-WIDTH -Wno-TIMESCALEMOD \
	-I$(HDL_DIR) \
	-DBOOTLOADER=\"$(BOOT_HEX)\" -DEXTERNAL_CLOCKS

ICE40_CELLS_SIM := $(shell yosys-config --datdir/ice40/cells_sim.v)

VLT_CXX_SOURCES = main.cpp ../VerilatorSimulation.cpp

VLT_CFLAGS := -std=c++14 $(CXX_OPT) $(shell sdl2-config --cflags) -I../ -DSIM_VERILATOR

VLT_LDFLAGS := $(shell sdl2-config --libs)

verilator_sim_trace: VLT_CFLAGS += -DVCD_WRITE=1
verilator_sim_trace: VLT_FLAGS += --trace

# Verilator already manages dependnecies, generates its own Makefile, forwards your C/LDFLAGS etc.
# There is no need to duplicate that effort here, just invokve it everytime and it'll only do
# work if necessary.

define build-verilator-sim
	set -e ;\
	verilator $(VLT_FLAGS) -o $(SIM_NAME) \
		--top-module $(HDL_TOP) $(HDL_SOURCES) $(HDL_TOP).v $(ICE40_CELLS_SIM) \
		-CFLAGS "$(VLT_CFLAGS)" -LDFLAGS "$(VLT_LDFLAGS)" --exe $(VLT_CXX_SOURCES) ;\
	make -C obj_dir/ -f V$(HDL_TOP).mk ;\
	cp obj_dir/$(SIM_NAME) $@
endef

verilator_sim:
	$(build-verilator-sim)

verilator_sim_trace:
	$(build-verilator-sim)

.PHONY: verilator_sim verilator_sim_trace
