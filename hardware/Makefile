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

CXXRTL_CFLAGS := $(shell sdl2-config --cflags)
CXXRTL_LDFLAGS := $(shell sdl2-config --libs)

cxxrtl_sim: cxxrtl_sim.cpp $(CXXRTL_SRCS)
	g++ -std=c++14 -O3 -I/Users/dan.rodrigues/hw/icetools/yosys $(CXXRTL_SRCS) $(CXXRTL_CFLAGS) $(CXXRTL_LDFLAGS) -o $@

cxxrtl_sim.cpp: $(SOURCES) $(BOOT_HEX)
	yosys -p 'verilog_defines -DBOOTLOADER="$(BOOT_HEX)" -DVERILATOR; read_verilog ics32_tb.v sim/sim_spiflash.v $(SOURCES); techmap -autoproc -map ./cells_sim.v; hierarchy -check -top ics32_tb; prep -top ics32_tb; flatten; opt; write_cxxrtl -O0 $@'

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

