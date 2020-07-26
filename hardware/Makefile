# Video mode selection:
#
# Supported video modes:
# - VM_640x480 (25Mhz)
# - VM_848x480 (33.75MHz)

# VIDEO_MODE = VM_640x480
VIDEO_MODE = VM_848x480

###

PROJ = system

PIN_DEF = icebreaker.pcf
DEVICE = up5k
PACKAGE = sg48

BOOT_DIR = ../firmware/
BOOT_HEX = $(BOOT_DIR)boot.hex

TOP = ics32_top_icebreaker

YOSYS_SYNTH_FLAGS = -dffe_min_ce_use 4 -dsp -top $(TOP)
YOSYS_DEFINE_ARGS := -f 'verilog -DBOOTLOADER="$(BOOT_HEX)"'

include sources.mk

# iCEBreaker specific for now
SOURCES += icebreaker/$(TOP).v
SOURCES += $(ICEBREAKER_SRCS)

# Timing constraints vary according to video mode
TIMING_PY := constraints/$(VIDEO_MODE).py 

main-build: pre-build
	@$(MAKE) --no-print-directory $(PROJ).bit

pre-build:
	@$(MAKE) -C $(BOOT_DIR)

###

$(PROJ).json: $(SOURCES) $(BOOT_HEX)
	yosys $(YOSYS_DEFINE_ARGS) -p 'chparam -set ENABLE_WIDESCREEN 0 ics32_top_icebreaker; synth_ice40 $(YOSYS_SYNTH_FLAGS) -json $@' $(SOURCES)

count: $(SOURCES) $(BOOT_HEX)
	yosys $(YOSYS_DEFINE_ARGS) -p 'synth_ice40 $(YOSYS_SYNTH_FLAGS) -noflatten' $(SOURCES)

%.asc: $(PIN_DEF) %.json
	nextpnr-ice40 --$(DEVICE) $(if $(PACKAGE),--package $(PACKAGE)) $(if $(FREQ),--freq $(FREQ)) --json $(filter-out $<,$^) --placer heap --pcf $< --asc $@ --pre-pack $(TIMING_PY) --seed 0

%.bit: %.asc
	icepack $< $@

prog: $(PROJ).bit
	iceprog $<

clean:
	rm -f $(PROJ).asc $(PROJ).rpt $(PROJ).bit $(PROJ).json

.SECONDARY:
.PHONY: main-build prog clean count

