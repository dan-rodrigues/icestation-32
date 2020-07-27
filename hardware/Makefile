# Video mode selection:
#
# Supported video modes:
# - VM_640x480 (25Mhz)
# - VM_848x480 (33.75MHz)

# VIDEO_MODE = VM_640x480
VIDEO_MODE = VM_848x480

###

ICEBREAKER_PREFIX = icebreaker

PROJ = $(ICEBREAKER_PREFIX)

### Device specific

ICE40_DEVICE = up5k
ICE40_PACKAGE = sg48

ECP5_PACKAGE = CABGA381
ECP5_SIZE = 85

###

ICEBREAKER_PIN_DEF = icebreaker/icebreaker.pcf
ULX3S_PIN_DEF = ulx3s/ulx3s_v20.lpf

BOOT_DIR = ../firmware/
BOOT_HEX = $(BOOT_DIR)boot.hex

icebreaker.json: TOP = ics32_top_icebreaker
ulx3s.json: TOP = ics32_top_ulx3s

include sources.mk

icebreaker.json: SOURCES += $(ICEBREAKER_SRCS) icebreaker/$(TOP).v
ulx3s.json: SOURCES += $(ULX3S_SRCS) ulx3s/$(TOP).v

# Timing constraints vary according to video mode
TIMING_PY := constraints/$(VIDEO_MODE).py 

ifeq ($(VIDEO_MODE), VM_848x480)
	ENABLE_WIDESCREEN = 1
else
	ENABLE_WIDESCREEN = 0
endif

main-build: pre-build
	# This invokes the default target, which has to be preselected somehow
	@$(MAKE) --no-print-directory $(PROJ).bit

pre-build:
	@$(MAKE) -C $(BOOT_DIR)

###

# Supported board targets:

icebreaker: icebreaker.bit
	
ulx3s: ulx3s.svf

# move into target if possible?

define synth
	yosys $(YOSYS_DEFINE_ARGS) -p 'chparam -set ENABLE_WIDESCREEN $(ENABLE_WIDESCREEN) $(TOP); $(YOSYS_SYNTH_COMMAND) $(YOSYS_SYNTH_FLAGS) -json $@' $(SOURCES)
endef

icebreaker.json: YOSYS_SYNTH_COMMAND = synth_ice40
ulx3s.json: YOSYS_SYNTH_COMMAND = synth_ecp5

icebreaker.json: YOSYS_SYNTH_FLAGS = -dffe_min_ce_use 4 -dsp -top $(TOP)
ulx3s.json: YOSYS_SYNTH_FLAGS = -top $(TOP)

YOSYS_DEFINE_ARGS := -f 'verilog -DBOOTLOADER="$(BOOT_HEX)"'

### Common ###

%.json: $(SOURCES) $(BOOT_HEX)
	$(call synth)

count: $(SOURCES) $(BOOT_HEX)
	yosys $(YOSYS_DEFINE_ARGS) -p 'chparam -set ENABLE_WIDESCREEN $(ENABLE_WIDESCREEN) $(TOP); synth_ice40 $(YOSYS_SYNTH_FLAGS) -noflatten' $(SOURCES)

### iCE40 ###

%.asc: $(ICEBREAKER_PIN_DEF) %.json
	nextpnr-ice40 --$(DEVICE) $(if $(PACKAGE),--package $(PACKAGE)) $(if $(FREQ),--freq $(FREQ)) --json $(filter-out $<,$^) --placer heap --pcf $< --asc $@ --pre-pack $(TIMING_PY) --seed 0

%.bit: %.asc
	icepack $< $@

prog: $(PROJ).bit
	iceprog $<

clean:
	rm -f $(PROJ).asc $(PROJ).rpt $(PROJ).bit $(PROJ).json

### ECP5 ###

%.config: $(ULX3S_PIN_DEF) %.json
	nextpnr-ecp5 --package $(ECP5_PACKAGE) --$(ECP5_SIZE)k $(if $(FREQ),--freq $(FREQ)) --json $(filter-out $<,$^) --placer heap --lpf $< --textcfg $@ --pre-pack $(TIMING_PY) --seed 0

%.svf: %.config
	ecppack --input $< --svf $@

.SECONDARY:
.PHONY: main-build prog clean count

