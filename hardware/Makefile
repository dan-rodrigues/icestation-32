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

cxxrtl_sim: cxxrtl_sim.cpp
	g++ -std=c++14 -I/Users/dan.rodrigues/hw/icetools/yosys $(CXXRTL_SRCS) -o $@

cxxrtl_sim.cpp: $(SOURCES) $(BOOT_HEX)
	yosys -p 'verilog_defines -DBOOTLOADER="$(BOOT_HEX)" -DVERILATOR; read_verilog $(SOURCES); techmap -autoproc -map ./cells_sim.v; hierarchy -check -top ics32; prep -top ics32 -flatten; write_cxxrtl -O0 $@'

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

