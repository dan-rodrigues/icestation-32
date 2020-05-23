# VGA simulator

This is the WIP simulator used to simulate the system with VGA output.

Note that versions of Verilator 4.008 and newer don't seem to work with the current sources, although it does synthesize and run on the FPGA with the current Yosys toolchains. Newer verilator versions are much tougher in terms of enforcing the IEEE spec.

The sources are currently being upgraded to work with the newest versions of Verilator.

## Prerequisites

* Verilator
* Yosys (required for the included iCE40 cell sim libraries)
* SDL2

## Usage

`SDL_PATH` in `build.sh` must be set to your SDL2 install directory

```
./build.sh
cd /obj_dir
./ics32-sim <program binary path>
```

An example script is included to build and run the sprites demo in one step. Note that this example script assumes a GNU RISC-V toolchain is already installed and configured in its Makefile.

```
./build-and-run-sprites-demo.sh
```
