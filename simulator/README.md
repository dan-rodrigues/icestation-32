# VGA simulator

This is the WIP simulator used to simulate the system with VGA output.

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
