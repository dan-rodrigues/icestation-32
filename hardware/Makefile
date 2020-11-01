# Video mode selection:
#
# Supported video modes:
# - VM_640x480 (25Mhz)
# - VM_848x480 (33.75MHz)

# VIDEO_MODE = VM_640x480
VIDEO_MODE = VM_848x480

###

# Boot firmware rules

include ../firmware/boot.mk

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

icebreaker.json: TOP = ics32_top_icebreaker
ulx3s.json: TOP = ics32_top_ulx3s
count: TOP = ics32_top_icebreaker

include sources.mk

icebreaker.json: SOURCES += $(ICEBREAKER_SOURCES) icebreaker/$(TOP).v
ulx3s.json: SOURCES += $(ULX3S_SOURCES) ulx3s/$(TOP).v
count: SOURCES += $(ICEBREAKER_SOURCES) icebreaker/$(TOP).v

# Timing constraints vary according to video mode
TIMING_PY := constraints/$(VIDEO_MODE).py 

ifeq ($(VIDEO_MODE), VM_848x480)
ENABLE_WIDESCREEN = 1
else
ENABLE_WIDESCREEN = 0
endif

### Supported board targets:

icebreaker: icebreaker.bit
ulx3s: ulx3s.bit

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

icebreaker.json: BOOT_HEX_SELECTED = $(BOOT_HEX)
ulx3s.json: BOOT_HEX_SELECTED = $(BOOT_MULTI_HEX)

YOSYS_DEFINE_ARGS = -f 'verilog -DBOOTLOADER="$(BOOT_HEX_SELECTED)"'

### Common ###

ulx3s.json: $(SOURCES) $(ULX3S_SOURCES) ulx3s/ics32_top_ulx3s.v $(BOOT_MULTI_HEX) $(BOOT_MULTI_NOIPL_BIN)
	$(call synth, -json $@)

icebreaker.json: $(SOURCES) $(ICEBREAKER_SOURCES) icebreaker/ics32_top_icebreaker.v $(BOOT_HEX)
	$(call synth, -json $@)

count: $(SOURCES) $(BOOT_HEX)
	$(call synth, -noflatten)

clean: boot_clean
	rm -f \
		$(ICEBREAKER_PREFIX).asc $(ICEBREAKER_PREFIX).rpt $(ICEBREAKER_PREFIX).bit $(ICEBREAKER_PREFIX).json \
		$(ULX3S_PREFIX).config $(ULX3S_PREFIX).bit $(ULX3S_PREFIX).json $(ULX3S_PREFIX)_pnr.json

### iCE40 ###

%.asc: $(ICEBREAKER_PIN_DEF) %.json
	nextpnr-ice40 --$(ICE40_DEVICE) --package $(ICE40_PACKAGE) --json $(filter-out $<,$^) --placer heap --pcf $< --asc $@ --pre-pack $(TIMING_PY) --seed 0

icebreaker.bit: icebreaker.asc
	icepack $< $@

icebreaker_prog: $(ICEBREAKER_PREFIX).bit
	iceprog $<

### ECP5 ###

%.config: $(ULX3S_PIN_DEF) %.json
	nextpnr-ecp5 --package $(ECP5_PACKAGE) --$(ECP5_SIZE)k --json $(filter-out $<,$^) --placer heap --lpf $< --textcfg $@ --write $(@:.config=_pnr.json) --pre-pack $(TIMING_PY) --seed 0

ulx3s.bit: ulx3s.config
	ecppack --input $< --bit $@

ulx3s_prog: $(ULX3S_PREFIX).bit
	fujprog -j flash $<

.SECONDARY:
.PHONY: main-build icebreaker_prog ulx3s_prog clean count

