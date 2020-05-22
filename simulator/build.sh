#!/bin/bash

EXTRA_VLT_FLAGS=$1
VLT_FLAGS="-cc -v config.vlt -O3 --compiler clang --assert -Wall -Wno-fatal -Wno-WIDTH"

SIM_NAME=ics32-sim

TOP_MODULE=ics32_tb
RTL_INCLUDE="-I../hardware -I../hardware/vdp -I../hardware/sim"
SDL_PATH="/usr/local/opt/sdl2"

CXX_SOURCES="main.cpp"
CFLAGS="-std=c++14 -Os -I${SDL_PATH}/include/SDL2"
LDFLAGS="-L${SDL_PATH}/lib -lSDL2"

ICE40_CELLS_SIM=$(yosys-config --datdir/ice40/cells_sim.v)

verilator ${VLT_FLAGS} ${EXTRA_VLT_FLAGS} -o ${SIM_NAME} ${RTL_INCLUDE} --top-module "${TOP_MODULE}" "${TOP_MODULE}".v "${ICE40_CELLS_SIM}" -CFLAGS "${CFLAGS}" -LDFLAGS "${LDFLAGS}" --exe "${CXX_SOURCES}"

cd ./obj_dir
make -f V"${TOP_MODULE}".mk

