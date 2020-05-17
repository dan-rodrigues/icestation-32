PROJ = system

PIN_DEF = icebreaker.pcf
DEVICE = up5k
PACKAGE = sg48

include sources.mk

all: $(PROJ).bit

$(PROJ).json: $(SOURCES)
	yosys -p 'synth_ice40 -dsp -top ics32 -json $@' $(SOURCES)

count: $(SOURCES)
	yosys -p 'synth_ice40 -noflatten -dsp -top ics32' $(SOURCES)

%.asc: $(PIN_DEF) %.json
	nextpnr-ice40 --$(DEVICE) $(if $(PACKAGE),--package $(PACKAGE)) $(if $(FREQ),--freq $(FREQ)) --json $(filter-out $<,$^) --placer heap --pcf $< --asc $@ --pre-pack timing.py --seed 0

%.bit: %.asc
	icepack -s $< $@

prog: $(PROJ).bit
	iceprog $<

clean:
	rm -f $(PROJ).asc $(PROJ).rpt $(PROJ).bit $(PROJ).json

.SECONDARY:
.PHONY: all prog clean count
