#!/bin/bash

# Build the sprites demo
make -C ../software/sprites

# Build the simulator
./build.sh

# Run the sprites demo in the simulator
./obj_dir/ics32-sim ../software/sprites/prog.bin

