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

main-build: pre-build
	@$(MAKE) --no-print-directory $(PROJ).bit

pre-build:
	@$(MAKE) -C $(BOOT_DIR)

###

$(PROJ).json: $(SOURCES) $(BOOT_HEX)
	yosys $(YOSYS_DEFINE_ARGS) -p 'synth_ice40 $(YOSYS_SYNTH_FLAGS) -json $@' $(SOURCES)

count: $(SOURCES) $(BOOT_HEX)
	yosys $(YOSYS_DEFINE_ARGS) -p 'synth_ice40 $(YOSYS_SYNTH_FLAGS) -noflatten' $(SOURCES)

%.asc: $(PIN_DEF) %.json
	nextpnr-ice40 --$(DEVICE) $(if $(PACKAGE),--package $(PACKAGE)) $(if $(FREQ),--freq $(FREQ)) --json $(filter-out $<,$^) --placer heap --pcf $< --asc $@ --pre-pack timing.py --seed 0

%.bit: %.asc
	icepack $< $@

prog: $(PROJ).bit
	iceprog $<

clean:
	rm -f $(PROJ).asc $(PROJ).rpt $(PROJ).bit $(PROJ).json

.SECONDARY:
.PHONY: main-build prog clean count

