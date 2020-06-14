# VGA simulator

This is the WIP simulator used to simulate the system with VGA output.

## Prerequisites

* Yosys (required for the included iCE40 cell sim libraries)
* SDL2
* Verilator, if the Verilator implementation of the simulation is used

## Usage

### Verilator

```console
make verilator_sim
./verilator_sim <program-file-path>
```

### CXXRTL

```console
make cxxrtl_sim
./cxxrtl_sim <program-file-path>
```

## Quickstart

An example script is included to build and run the sprites demo in one step. Note that this example script assumes a GNU RISC-V toolchain is already installed and configured in its Makefile.

```console
./build-and-run-sprites-demo.sh
```
## Tool versions used for testing

* Verilator: 4.034
* CXXRTL (yosys commit): `74e93e08`

## TODO

* Refine and extend the `_trace` targets
* Any possible correctness / performance improvements for the yosys script used prior to `write_cxxrtl`