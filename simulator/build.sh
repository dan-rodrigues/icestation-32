#!/bin/bash

ICE40_CELLS_SIM=$(yosys-config --datdir/ice40/cells_sim.v)

verilator -cc -v config.vlt -I../hardware -I../hardware/vdp -I../hardware/sim --assert -Wall --trace -Wno-fatal -Wno-WIDTH --top-module ics32_tb ics32_tb.v "${ICE40_CELLS_SIM}"
