#!/bin/sh

# TMDS clock: 33.75 * 5 = 168.75
# System clock: 33.75
# System clock / 2: 16.875 (optional)

ecppll -i 25 -o 168.75 --clkout3 16.875 --clkout2 33.75 -f generated_pll.v

