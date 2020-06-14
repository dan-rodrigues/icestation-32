#!/bin/bash

# Build the sprites demo
make -C ../software/sprites

# Build the simulator
make verilator_sim

# Run the sprites demo in the simulator
./verilator_sim ../software/sprites/prog.bin

