# Video mode selection:
#
# Supported video modes:
# - VM_640x480 (25Mhz)
# - VM_848x480 (33.75MHz)

# VIDEO_MODE = VM_640x480
VIDEO_MODE = VM_848x480

###

ICEBREAKER_PREFIX = icebreaker
ULX3S_PREFIX = ulx3s

DEFAULT_PREFIX = $(ICEBREAKER_PREFIX)

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
count: TOP = ics32_top_icebreaker

include sources.mk

icebreaker.json: SOURCES += $(ICEBREAKER_SRCS) icebreaker/$(TOP).v
ulx3s.json: SOURCES += $(ULX3S_SRCS) ulx3s/$(TOP).v
count: SOURCES += $(ICEBREAKER_SRCS) icebreaker/$(TOP).v

# Timing constraints vary according to video mode
TIMING_PY := constraints/$(VIDEO_MODE).py 

ifeq ($(VIDEO_MODE), VM_848x480)
	ENABLE_WIDESCREEN = 1
else
	ENABLE_WIDESCREEN = 0
endif

### Supported board targets:

icebreaker: icebreaker.bit
ulx3s: ulx3s.svf

.PHONY: icebreaker ulx3s

###

define synth
	yosys $(YOSYS_DEFINE_ARGS) -p \
		'chparam -set ENABLE_WIDESCREEN $(ENABLE_WIDESCREEN) $(TOP); \
		$(YOSYS_SYNTH_COMMAND) $(YOSYS_SYNTH_FLAGS) $1' \
		$(SOURCES)
endef

icebreaker.json: YOSYS_SYNTH_COMMAND = synth_ice40
ulx3s.json: YOSYS_SYNTH_COMMAND = synth_ecp5
count: YOSYS_SYNTH_COMMAND = synth_ice40

icebreaker.json: YOSYS_SYNTH_FLAGS = -dffe_min_ce_use 4 -dsp -top $(TOP)
ulx3s.json: YOSYS_SYNTH_FLAGS = -top $(TOP)
count: YOSYS_SYNTH_FLAGS = -dffe_min_ce_use 4 -dsp -top $(TOP)

YOSYS_DEFINE_ARGS := -f 'verilog -DBOOTLOADER="$(BOOT_HEX)"'

### Common ###

# Build firmware and any downstream dependencies if needed

# .SHELLSTATUS could be used instead of doing this but is limited to newer Make verisons
# Ideally the error could be printed here instead of having to be redirected to /dev/null

BOOT_BUILD_STATUS := $(shell $(MAKE) -C $(BOOT_DIR) > /dev/null 2>&1; echo $$?)
ifneq ($(BOOT_BUILD_STATUS), 0)
$(error Failed to build firmware (boot.hex). Run "make" in ../firmware/ to see error details.)
endif

ulx3s.json: $(SOURCES) $(ULX3S_SRCS) ulx3s/ics32_top_ulx3s.v $(BOOT_HEX)
	$(call synth, -json $@)

icebreaker.json: $(SOURCES) $(ICEBREAKER_SRCS) icebreaker/ics32_top_icebreaker.v $(BOOT_HEX)
	$(call synth, -json $@)

count: $(SOURCES) $(BOOT_HEX)
	$(call synth, -noflatten)

clean:
	rm -f \
		$(ICEBREAKER_PREFIX).asc $(ICEBREAKER_PREFIX).rpt $(ICEBREAKER_PREFIX).bit $(ICEBREAKER_PREFIX).json \
		$(ULX3S_PREFIX).config $(ULX3S_PREFIX).svf $(ULX3S_PREFIX).json

### iCE40 ###

%.asc: $(ICEBREAKER_PIN_DEF) %.json
	nextpnr-ice40 --$(ICE40_DEVICE) --package $(ICE40_PACKAGE) --json $(filter-out $<,$^) --placer heap --pcf $< --asc $@ --pre-pack $(TIMING_PY) --seed 0

%.bit: %.asc
	icepack $< $@

icebreaker_prog: $(ICEBREAKER_PREFIX).bit
	iceprog $<

### ECP5 ###

%.config: $(ULX3S_PIN_DEF) %.json
	nextpnr-ecp5 --package $(ECP5_PACKAGE) --$(ECP5_SIZE)k --json $(filter-out $<,$^) --placer heap --lpf $< --textcfg $@ --pre-pack $(TIMING_PY) --seed 0

%.svf: %.config
	ecppack --input $< --svf $@

ulx3s_prog: $(ULX3S_PREFIX).svf
	fujprog $<

.SECONDARY:
.PHONY: main-build icebreaker_prog ulx3s_prog clean count

