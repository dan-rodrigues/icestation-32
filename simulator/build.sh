#!/bin/bash

SH_DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)

SIM_NAME=ics32-sim
CXX_SOURCES="main.cpp"

BOOT_DIR="${SH_DIR}/../firmware"
BOOT_HEX="${BOOT_DIR}/boot.hex"

EXTRA_VLT_FLAGS=$1
VLT_FLAGS="	-cc --language 1364-2005 -v config.vlt -O3 --assert \
		   	-Wall -Wno-fatal -Wno-WIDTH -Wno-TIMESCALEMOD \
			-DBOOTLOADER=\"${BOOT_HEX}\""

TOP_MODULE=ics32_tb
RTL_INCLUDE="-I../hardware -I../hardware/vdp -I../hardware/sim"

CFLAGS="-std=c++14 -Os $(sdl2-config --cflags)"
LDFLAGS=$(sdl2-config --libs)

ICE40_CELLS_SIM=$(yosys-config --datdir/ice40/cells_sim.v)

###

make -C ${BOOT_DIR}

verilator ${VLT_FLAGS} ${EXTRA_VLT_FLAGS} -o ${SIM_NAME} ${RTL_INCLUDE} \
	--top-module "${TOP_MODULE}" "${TOP_MODULE}".v "${ICE40_CELLS_SIM}" \
	-CFLAGS "${CFLAGS}" -LDFLAGS "${LDFLAGS}" --exe "${CXX_SOURCES}"

cd ./obj_dir
make -f V"${TOP_MODULE}".mk

