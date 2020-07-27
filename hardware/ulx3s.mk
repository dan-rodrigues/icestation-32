# Video mode selection:
#
# Supported video modes:
# - VM_640x480 (25Mhz)
# - VM_848x480 (33.75MHz)

# VIDEO_MODE = VM_640x480
VIDEO_MODE = VM_848x480

###

PROJ = system

PIN_DEF = ulx3s/ulx3s_v20.lpf
PACKAGE = CABGA381
ECP5_SIZE = 85

BOOT_DIR = ../firmware/
BOOT_HEX = $(BOOT_DIR)boot.hex

TOP = ics32_top_ulx3s

YOSYS_SYNTH_FLAGS = -top $(TOP)
YOSYS_DEFINE_ARGS := -f 'verilog -DBOOTLOADER="$(BOOT_HEX)"'

include sources.mk

# iCEBreaker specific for now
SOURCES += ulx3s/$(TOP).v
# SOURCES += $(ICEBREAKER_SRCS)
SOURCES += $(ULX3S_SRCS)

# Timing constraints vary according to video mode
TIMING_PY := constraints/$(VIDEO_MODE).py 

ifeq ($(VIDEO_MODE), VM_848x480)
	ENABLE_WIDESCREEN = 1
else
	ENABLE_WIDESCREEN = 0
endif

main-build: pre-build
	@$(MAKE) -f ulx3s.mk --no-print-directory $(PROJ).svf

# FIXME: original makefile needs to be invoked here (ulx3s if separate files are to be used)
pre-build:
	@$(MAKE) -C $(BOOT_DIR)

###

$(PROJ).json: $(SOURCES) $(BOOT_HEX)
	yosys $(YOSYS_DEFINE_ARGS) -p 'chparam -set ENABLE_WIDESCREEN $(ENABLE_WIDESCREEN) $(TOP); synth_ecp5 $(YOSYS_SYNTH_FLAGS) -json $@' $(SOURCES)

count: $(SOURCES) $(BOOT_HEX)
	yosys $(YOSYS_DEFINE_ARGS) -p 'chparam -set ENABLE_WIDESCREEN $(ENABLE_WIDESCREEN) $(TOP); synth_ecp5 $(YOSYS_SYNTH_FLAGS) -noflatten' $(SOURCES)

%.config: $(PIN_DEF) %.json
	nextpnr-ecp5 --package $(PACKAGE) --$(ECP5_SIZE)k $(if $(FREQ),--freq $(FREQ)) --json $(filter-out $<,$^) --placer heap --lpf $< --textcfg $@ --pre-pack $(TIMING_PY) --seed 0

%.svf: %.config
	ecppack --input $< --svf $@

# TODO: fujprog
prog: $(PROJ).svf
	fujprog $<

clean:
	rm -f $(PROJ).asc $(PROJ).rpt $(PROJ).bit $(PROJ).json

.SECONDARY:
.PHONY: main-build prog clean count

