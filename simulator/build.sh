#!/bin/bash

SIM_NAME=ics32-sim

TOP_MODULE=ics32_tb
RTL_INCLUDE="-I../hardware -I../hardware/vdp -I../hardware/sim"
SDL_PATH="/usr/local/opt/sdl2/"

CXX_SOURCES="main.cpp"
CFLAGS="-std=c++14 -I${SDL_PATH}include/SDL2/"
LDFLAGS="-L${SDL_PATH}/lib -lSDL2"

ICE40_CELLS_SIM=$(yosys-config --datdir/ice40/cells_sim.v)

verilator -cc -v config.vlt --compiler clang -o ${SIM_NAME} ${RTL_INCLUDE} --assert -Wall --trace -Wno-fatal -Wno-WIDTH --top-module "${TOP_MODULE}" "${TOP_MODULE}".v "${ICE40_CELLS_SIM}" -CFLAGS "${CFLAGS}" -LDFLAGS "${LDFLAGS}" --exe "${CXX_SOURCES}"

cd ./obj_dir
make -f V"${TOP_MODULE}".mk

