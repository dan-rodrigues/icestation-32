# Demo software

A few demo applications are included so far:

## Prerequisites

* GNU RISC-V toolchain

The `CROSS` variable in `common/common.mk` must be set according to the name of your RISC-V installation.

## `sprites/`

Animated sprites demo. A palette-based PNG file is converted to the ics-32 format and compiled into the demo. This demo also shows alpha blending of sprites onto a variable backgroud color.

![sprites demo](screenshots/sprites.png)

## `hello_world/`

Minimal example using a single scrolling layer to display monochrome text.

![hello_world demo](screenshots/hello_world.png)

## Other demos

(Twitter)

## Acknowledgements

* [Rotating crystal graphics](https://opengameart.org/content/rotating-crystal-animation-8-step) by qubodup
* [8x8 font](https://github.com/dhepper/font8x8) by dhepper
