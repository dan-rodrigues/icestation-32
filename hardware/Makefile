PROJ = system

PIN_DEF = icebreaker.pcf
DEVICE = up5k
PACKAGE = sg48

BOOT_DIR = ../firmware/
BOOT_HEX = $(BOOT_DIR)boot.hex

YOSYS_SYNTH_FLAGS = -dffe_min_ce_use 4 -dsp -top ics32
YOSYS_DEFINE_ARGS := -f 'verilog -DBOOTLOADER="$(BOOT_HEX)"'

CXXRTL_SRCS = ../simulator/cxxrtl/main.cpp

include sources.mk

main-build: pre-build
	@$(MAKE) --no-print-directory $(PROJ).bit

pre-build:
	@$(MAKE) -C $(BOOT_DIR)

###

# iverilog

iverilog_sim: $(SOURCES) $(BOOT_HEX)
	iverilog -Wall -DBOOTLOADER="$(BOOT_HEX)" -DVERILATOR=1 -o sim.vvp cells_sim.v sim/sim_spiflash.v $(SOURCES) ics32_tb.v ics32_ivl_tb.v
	
# new cxxrtl stuff, to cleanup at some point

CXXRTL_CFLAGS := $(shell sdl2-config --cflags)
CXXRTL_LDFLAGS := $(shell sdl2-config --libs)
CXXRTL_OPT = -O3
CXXRTL_INCLUDES := $(HOME)/hw/icetools/yosys

crgh:
	yosys -p \
		'read_ilang ics_build_errors.ilang; \
		write_cxxrtl -O5 sim.cpp'
	g++ -std=c++14 -DCXXRTL_INCLUDE_VCD_CAPI_IMPL -I/Users/dan.rodrigues/hw/icetools/yosys -c sim.cpp -o sim.o

crsim_pre: crsim_pre.cpp $(CXXRTL_SRCS)
	g++ -std=c++14 -DCXXRTL_INCLUDE_VCD_CAPI_IMPL $(CXXRTL_OPT) -I$(CXXRTL_INCLUDES) $(CXXRTL_SRCS) $(CXXRTL_CFLAGS) $(CXXRTL_LDFLAGS) -o $@

# ...
crsim_post: crsim_post.cpp $(CXXRTL_SRCS)
	g++ -std=c++14 -DCXXRTL_INCLUDE_VCD_CAPI_IMPL $(CXXRTL_OPT) -I$(CXXRTL_INCLUDES) $(CXXRTL_SRCS) $(CXXRTL_CFLAGS) $(CXXRTL_LDFLAGS) -o $@

crsim_ilang: crsim_ilang.cpp $(CXXRTL_SRCS)
	g++ -std=c++14 -I$(CXXRTL_INCLUDES) $(CXXRTL_SRCS) $(CXXRTL_CFLAGS) $(CXXRTL_LDFLAGS) -o $@

crsim_ilang.cpp: $(SOURCES) $(BOOT_HEX)
	yosys -p \
		'read_ilang ics_build_errors.ilang; \
		write_cxxrtl -O3 $@'

crsim_pre.cpp: $(SOURCES) $(BOOT_HEX)
	yosys -p \
	'verilog_defines -DBOOTLOADER="$(BOOT_HEX)" -DVERILATOR -DEXTERNAL_CLOCKS -DDEBUGNETS; \
		read_verilog ics32_tb.v cells_sim.v sim/sim_spiflash.v $(SOURCES); \
		proc; flatten; \
		write_ilang ics_build_errors.ilang; \
		write_cxxrtl -O5 $@'

crsim_post.cpp: $(SOURCES) $(BOOT_HEX)
	yosys -p \
        'verilog_defines -DBOOTLOADER="$(BOOT_HEX)" -DVERILATOR; \
		read_verilog ics32_tb.v sim/sim_spiflash.v $(SOURCES); \
        techmap -autoproc -map ./cells_sim.v; \
        hierarchy -check -top ics32_tb; \
        prep -top ics32_tb -flatten; \
        memory -nomap; \
		write_cxxrtl -O5 $@'

###

$(PROJ).json: $(SOURCES) $(BOOT_HEX)
	yosys $(YOSYS_DEFINE_ARGS) -p 'synth_ice40 $(YOSYS_SYNTH_FLAGS) -json $@' $(SOURCES)

count: $(SOURCES) $(BOOT_HEX)
	yosys $(YOSYS_DEFINE_ARGS) -p 'synth_ice40 $(YOSYS_SYNTH_FLAGS) -noflatten' $(SOURCES)

%.asc: $(PIN_DEF) %.json
	nextpnr-ice40 --$(DEVICE) $(if $(PACKAGE),--package $(PACKAGE)) $(if $(FREQ),--freq $(FREQ)) --json $(filter-out $<,$^) --placer heap --pcf $< --asc $@ --pre-pack timing.py --seed 0

%.bit: %.asc
	icepack -s $< $@

prog: $(PROJ).bit
	iceprog $<

clean:
	rm -f $(PROJ).asc $(PROJ).rpt $(PROJ).bit $(PROJ).json

.PHONY: main-build prog clean count

