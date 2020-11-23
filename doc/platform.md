Icestation-32 platform documentation
====================================

Icestation-32 is a compact open-source game console targeting small FPGAs. Because of this, facilities like RAM are quite minimalistic. It does however make good use of the flexibility of FPGAs to implement a custom VDP and audio processor. This allows for a surprising number of effects.

The goal of this document is to describe the SoC in enough detail to develop software without necessarily having to consult the verilog implementation. However, in case of doubt, the verilog source is the actual specification. Although a few examples are given in C, it has been tried to stay as language-agnostic as possible to allow for implementing software in other languages as well.

CPU
---

The main CPU is a single-core 32-bit RISC-V CPU implementing the `RV32I` ISA. This architecture has 31 general purpose registers. It has addition/subtraction, basic bit manipulation and control flow instructions, as well as memory stores and loads of 8/16/32 bits width. It most notably does *not* have multiplication or division instructions (but see [DSP](#dsp)).

Details about the CPU instruction set and bit patterns can be found in the [RISC-V spec](https://riscv.org//wp-content/uploads/2017/05/riscv-spec-v2.2.pdf), chapter 2. The privileged spec is not implemented.

Address space layout
--------------------

The Icestation-32 has a 32-bit flat address space. It is laid out with the RAM at the start, followed by memory-mapped peripherals and flash ROM.

```
    ┌─────────────┐ 0xffff_ffff
    │             │
    │             │
    │ reserved    │
    │             │
    │             │
    ├─────────────┤ 0x0200_0000
    │             │
    │             │
    │ flash       │
    │             │
    │             │
    ├─────────────┤ 0x0100_0000
    │             │
    │             │
    │ peripherals │
    │             │
    │             │
    ├─────────────┤ 0x0001_0000
    │ RAM         │
    └─────────────┘ 0x0000_0000
```

In detail:

| from          | to            | description                          |
|:------------- |:------------- |:------------------------------------ |
| `0x0000_0000` | `0x0000_ffff` | [CPU RAM](#cpu-ram)                  |
| `0x0001_0000` | `0x0001_ffff` | [VDP](#vdp)                          |
| `0x0002_0000` | `0x0002_ffff` | [System status](#system-status)      |
| `0x0003_0000` | `0x0003_ffff` | [DSP](#dsp)                          |
| `0x0004_0000` | `0x0004_ffff` | [Gamepad](#gamepad)                  |
| `0x0005_0000` | `0x0005_ffff` | [VDP "copper" RAM](#vdp-copper-ram)  |
| `0x0006_0000` | `0x0006_ffff` | [Bootloader ROM](#bootloader-rom)    |
| `0x0007_0000` | `0x0007_ffff` | [Flash control](#flash-control)      |
| `0x0008_0000` | `0x0008_ffff` | [Audio](#audio)                      |
| `0x0100_0000` | `0x01ff_ffff` | [CPU flash access](#flash-access)    |

The different peripherals are described in the following sections. Note that these are the assigned memory ranges in the address decoder, and often only a small part of the address space is used.

CPU RAM
=======

This is the main RAM of the RISC-V CPU. There is 64 kB of general purpose RAM available, implemented as BRAMs on the FPGA fabric (icestation-32 doesn't use external SDRAM chips). This RAM stores both code and data. At boot, the boot ROM fills this memory with its initial state from flash and jumps to address `0x0000_0000`.

VDP
===

Icestation-32 has a custom VDP with support for smooth-scrolling layers and sprites.

The display resolution can be `848×480` or `640×480`. The VDP can be considered to have a virtual display size of `1024×512`, of which the top-left portion is visible on the display output:

```
    0                 848   1024
  0 ┌──────────────────┬──────┐
    │                  ┊      │
    │     visible      ┊      │
    │     screen       ┊      │
    │     area         ┊      │
    │                  ┊      │
480 ├┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┘      │
    │                         │
    │            off-screen   │
512 └─────────────────────────┘
```

The screen rendering consists of two main components: one or multiple layers of "scroll map", and sprites. A scroll map layer consists of fixed-size indexed tiles, and as the name implies, can be scrolled. Sprites are small graphics that can be overlaid over the map at any position. Instead of scroll map layers, an affine layer can be enabled, which is a 256-color tiled image that can be "distorted" with an affine transformation matrix.

Registers
----------

The memory-mapped VDP registers are 16-bit, and laid out as follows:

```
reg    r/w bits     name                      description
------ --- -------  ------------------------  ----------------------------------------
0x0000  w  [15:0]   SPRITE_BLOCK_ADDRESS      Sprite metadata address register
0x0000  r  [15:0]   CURRENT_RASTER_X          Current display-out X position
0x0002  w  [15:0]   SPRITE_DATA               Sprite metadata write register
0x0004  w  [15:0]   PALETTE_ADDRESS           Palette address register
0x0004  r  [15:0]   CURRENT_RASTER_Y          Current display-out Y position
0x0006  w  [15:0]   PALETTE_WRITE_DATA        Palette data write register
0x0008  w  [15:0]   VRAM_ADDRESS              VRAM address register
0x000a  w  [15:0]   VRAM_WRITE_DATA           VRAM data write register
0x000c  w  [7:0]    ADDRESS_INCREMENT         Address increment after every VRAM write
0x000e  w  [15:0]   SPRITE_TILE_BASE          Tile offset for sprite layer
0x0010  w  [0]      ENABLE_COPPER             Enable "copper" coprocessor
0x0012  w  [15:0]   SCROLL_TILE_ADDRESS_BASE  Tile offset for scroll layers 0..3
0x0014  w  [15:0]   SCROLL_MAP_ADDRESS_BASE   Map offset for scroll layers 0..3
0x0016  w  [5:0]    LAYER_ENABLE              Enable layers display
0x0018  w  [4:0]    ALPHA_OVER_ENABLE         Enable layer alpha blending
0x001a  w  [3:0]    SCROLL_WIDE_MAP_ENABLE    Wide-map mode for scroll layers 0..3
0x0020  w  [15:0]   HSCROLL_0                 Horizontal offset for scroll layer 0
0x0020  w  [15:0]   AFFINE_TRANSLATE_X        Affine layer x-translation
0x0022  w  [15:0]   HSCROLL_1                 Horizontal offset for scroll layer 1
0x0022  w  [15:0]   MATRIX_A                  Affine matrix A
0x0024  w  [15:0]   HSCROLL_2                 Horizontal offset for scroll layer 2
0x0024  w  [15:0]   MATRIX_B                  Affine matrix B
0x0026  w  [15:0]   HSCROLL_3                 Horizontal offset for scroll layer 3
0x0026  w  [15:0]   MATRIX_C                  Affine matrix C
0x0028  w  [15:0]   VSCROLL_0                 Vertical offset for scroll layer 0
0x0028  w  [15:0]   MATRIX_D                  Affine matrix D
0x002a  w  [15:0]   VSCROLL_1                 Vertical offset for scroll layer 1
0x002a  w  [15:0]   AFFINE_TRANSLATE_Y        Affine layer y-translation
0x002c  w  [15:0]   VSCROLL_2                 Vertical offset for scroll layer 2
0x002c  w  [15:0]   AFFINE_PRETRANSLATE_X     Affine layer x-pretranslation
0x002e  w  [15:0]   VSCROLL_3                 Vertical offset for scroll layer 3
0x002e  w  [15:0]   AFFINE_PRETRANSLATE_Y     Affine layer y-pretranslation
```

The `HSCROLL_x` and `VSCROLL_x` registers are aliases for the affine transformation registers. How they are used depends on whether the affine layer is enabled. *Either* SCROLLx layers or the affine layer should be enabled, not both at the same time.

The only values that can be read from the VDP are `CURRENT_RASTER_X` and `CURRENT_RASTER_Y`, which are the current raster x and y coordinate that are being output, respectively. The rest is write-only from the point of view of the CPU.

VDP memory layout
-----------------

The VDP has its own 64 kB RAM. This VDP RAM is not directly accessible from the CPU, but it can be written indirectly through a pair of registers (address, data). It is not possible to read from VDP memory.

VDP memory is always addressed in 16-bit words, and all addresses are specified as such. So it's often convenient to regard it as 32768 (0x8000) words of memory.

As all memory offsets are configurable (the only exception is the affine layer), the VDP memory can be laid out arbitrarily. The following contents are stored in VDP memory:

- Tile graphics for scroll layers (configured through register `SCROLL_TILE_ADDRESS_BASE`).

- Tile graphics for sprites (configured through register `SPRITE_TILE_BASE`).

- Maps for the scroll layers. These select the indices for the tiles to show from the tile graphics (configured through register `SCROLL_MAP_ADDRESS_BASE`).

- Graphics and tile map for the affine layer (if enabled, always at address `0`).

To write to VDP memory, first write the index of the memory location to change to register `VRAM_ADDRESS`, then write the color to replace it with `VRAM_WRITE_DATA`. The auto-increment of the address after writes can be configured through `ADDRESS_INCREMENT`. Usually this register is set to 1, to quickly write adjacent VDP RAM memory locations.

Palette
-------

The VDP has a palette of 256 colors, where each color is 16-bit A4R4G4B4. The palette is, like the main VDP memory, written through a (address, data) pair of registers, but it is separate from the main memory. The palette represents all the colors that can be visible on the screen at the same time (aside from through copper effects).

For all uses except the affine payer the palette is considered as a matrix of 16 palettes of 16 entries. The eventual color for each layer is determined in the following way: the 4 most significant bits of the palette index come from the scroll map or sprite metadata, the 4 least significant bits come from the tile or sprite graphics itself. This 8-bit value is then looked up in the global palette to get a final color. The value 0 (from the sprite or scroll tile graphics) is treated specially: it means to show the background through. As palette index 0 is special within the 16-entry palettes it is not possible to use palette indices `0x10`, `0x20` to `0xf0`, except through the affine layer which is a true 256-color image.

To write to the palette, first write the index of the color to change to register `PALETTE_ADDRESS`, then write the color to replace it with `PALETTE_DATA`. The address auto-increments, so successive colors can be written simply by writing to `PALETTE_DATA` multiple times.

Layers
------

The main concept of rendering in the VDP is so-called layers. Layers are, as their name implies, overlaid over each other. In the absence of alpha blending, the lowest layer number that has a certain pixel enabled (that has a non-zero value for it) will take precedence, or the background color (palette index 0) if there is no such layer. Each layer has its own horizontal and vertical scroll offset. There are 3 scroll layers. The 4th layer still has registers reserved for it but was disabled due to VRAM usage constraints.

```
   ┌──────┐
   │     0│
   │      │──┐
   │      │ 1│
   │      │  │──┐
   └──────┘  │ 2│
      │      │  │
      └──────┘  │
         │      │
         └──────┘

    layers 0..2
```

Sprites are sometimes considered a layer, but might be best considered to be *between* scroll layers, not a layer in themselves. They have a priority as part of their individual metadata to determine this position: priority 0 sprites are behind layer 2, the hindmost layer, whereas priority 3 sprites are on top of layer 0. See the `aquarium` demo for an example.

Individual layers can be shown and hidden through the `LAYER_ENABLE` register:

```
                            LAYER_ENABLE

 15  14  13  12  11  10   9   8   7   6   5   4   3   2   1   0
┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
│ - │ - │ - │ - │ - │ - │ - │ - │ - │ - │AF │SPR│S3 │S2 │S1 │S0 │
└───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘

S0,S1,S2,S3: Enable scroll map layer 0,1,2,3 display, respectively.
SPR: Enable sprite display.
AF: Enable affine layer display.

A value of 1 enables (shows) the respective layer, a value
of 0 disables (hides) it.
```

Alpha blending
--------------

The VDP supports 4-bit alpha blending. In the case of alpha blending the final color for a layer is alpha-blended over the final color of the layer below it, or the background. Alpha-blending more than two layers will result in visual artifacts.

Post-multiplied alpha is used everywhere. This means that the color red green and blue component are multiplied with alpha color value before blending.

Alpha blending can be configured per layer through the `ALPHA_OVER_ENABLE` register.

```
                         ALPHA_OVER_ENABLE

 15  14  13  12  11  10   9   8   7   6   5   4   3   2   1   0
┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
│ - │ - │ - │ - │ - │ - │ - │ - │ - │ - │ - │SPR│S3 │S2 │S1 │S0 │
└───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘

S0,S1,S2,S3: Enable scroll map layer 0,1,2,3 alpha-over.
SPR: Enable alpha-over for sprites.

A value of 1 enables alpha-over for the respective layer, a value
of 0 disables it.
```

Tiles
-----

All tiles are sized 8×8. Tiles are stored in row-major order, with 4 bits per pixel. Each row of a tile is represented by two 16-bit integers, given colors A..H from left to right this becomes `{0xEFGH, 0xABCD}`:
```
     col
      A   B   C   D   E   F   G   H
row ┌───┬───┬───┬───┬───┬───┬───┬───┐
  0 │       1       │       0       │
    ├───┼───┼───┼───┼───┼───┼───┼───┤
  1 │       3       │       2       │
    ├───┼───┼───┼───┼───┼───┼───┼───┤
  2 │       5       │       4       │
    ├───┼───┼───┼───┼───┼───┼───┼───┤
  3 │       7       │       6       │
    ├───┼───┼───┼───┼───┼───┼───┼───┤
  4 │       9       │       8       │
    ├───┼───┼───┼───┼───┼───┼───┼───┤
  5 │      11       │      10       │
    ├───┼───┼───┼───┼───┼───┼───┼───┤
  6 │      13       │      12       │
    ├───┼───┼───┼───┼───┼───┼───┼───┤
  7 │      15       │      14       │
    └───┴───┴───┴───┴───┴───┴───┴───┘
```
This means that a tile spans 16 words, or 32 bytes of memory. The tile graphics are laid out in memory consecutively with increasing tile ids, starting at 0.

Let's say we want to make this little critter. Let's first draw him on a grid, then map the different shades to hexadecimal nibbles, and group these into 16-bit words:
```

     col
      A   B   C   D   E   F   G   H
row ┌───┬───┬───┬───┬───┬───┬───┬───┐  _ 0
  0 │ _ │ █ │ █ │ _ │ _ │ █ │ █ │ _ │  ░ 1     0x0440  0x0440
    ├───┼───┼───┼───┼───┼───┼───┼───┤  ▒ 2
  1 │ _ │ _ │ █ │ _ │ _ │ █ │ _ │ _ │  ▓ 3     0x0040  0x0400
    ├───┼───┼───┼───┼───┼───┼───┼───┤  █ 4
  2 │ _ │ _ │ ▓ │ ▓ │ ▓ │ ▓ │ _ │ _ │          0x0033  0x3300
    ├───┼───┼───┼───┼───┼───┼───┼───┤
  3 │ _ │ ▓ │ ▒ │ ▒ │ ▒ │ ▒ │ ▓ │ _ │          0x0322  0x2230
    ├───┼───┼───┼───┼───┼───┼───┼───┤   →
  4 │ _ │ ▓ │ _ │ ▒ │ ▒ │ _ │ ▓ │ _ │          0x0302  0x2030
    ├───┼───┼───┼───┼───┼───┼───┼───┤
  5 │ ░ │ ░ │ ░ │ ░ │ ░ │ ░ │ ░ │ ░ │          0x1111  0x1111
    ├───┼───┼───┼───┼───┼───┼───┼───┤
  6 │ ░ │ ░ │ ░ │ _ │ _ │ ░ │ ░ │ ░ │          0x1110  0x0111
    ├───┼───┼───┼───┼───┼───┼───┼───┤
  7 │ _ │ _ │ ▓ │ ▓ │ ▓ │ ▓ │ _ │ _ │          0x0033  0x3300
    └───┴───┴───┴───┴───┴───┴───┴───┘
```

Then swap the values horizontally, and concatenate them into an array:

```c
const uint16_t tile[] = {
    0x0440, 0x0440,
    0x0400, 0x0040,
    0x3300, 0x0033,
    0x2230, 0x0322,
    0x2030, 0x0302,
    0x1111, 0x1111,
    0x0111, 0x1110,
    0x3300, 0x0033,
};
```

Of course, this is only an example, doing this manually is not very convenient! See the function `upload_font_remapped_main` in `software/common/font.c`, or the `aquarium` demo for examples of building tile graphics on the fly from C. Alternatively the graphics can be converted from another format with some external tool like `utilities/gfx_convert`. SNES graphics editing tools may also be useful, as the idea is similar, though the exact storage format is not.

The tiles for the scroll map and for sprites have the same format. This means that it's possible for these to share the same graphics, which can be convenient as well as save memory.

Scroll map
----------

The scroll map is a grid of tiles of 8×8 pixels. There can be up to 512 distinct tiles, and each layer can have its own tile set.

Tiles can be flipped (mirrored) horizontally as well as vertically using per-tile flags. They can also specify their own palette to use out of 16 available.

The VDP scroll map memory layout consists of 64×64 tiles laid out in row-major order, with a 16-bit word per tile:

```
                  x
      0 .................... 63
     ┌────┬────┬─┈┈┈┈─┬────┬────┐
  0  │   0│   1│ .... │62  │63  │
  .  ├────┼────┼──┈┈──┼────┼────┤
  .  │  64│  65│ .... │126 │127 │
  .  ├────┼────┼──┈┈──┼────┼────┤
  .  ┆    ┆    ┆      ┆    ┆    ┆
y .  ┆    ┆    ┆ .... ┆    ┆    ┆
  .  ┆    ┆    ┆      ┆    ┆    ┆
  .  ├────┼────┼──┈┈──┼────┼────┤
  .  │  64│  65│ .... │126 │127 │
  .  ├────┼────┼──┈┈──┼────┼────┤
  63 │4032│4033│ .... │4094│4095│
     └────┴────┴─┈┈┈┈─┴────┴────┘
```

This word for every tile specifies the tile id `TILEID`, x-flip bit `XF`, y-flip bit `YF`, and palette `PAL`:

```
                          scroll_map_tile

 15  14  13  12  11  10   9   8   7   6   5   4   3   2   1   0
┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
│      PAL      │ - │YF │XF │            TILEID                 │
└───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘

TILEID: base tile id
XF: flip tile in x direction
YF: flip tile in y direction
PAL: the palette to use for this tile (upper 4 bits of palette index)
```

Layers can be of two kinds: "wide map" layers which are 128 by 64 tiles (1024×512 pixels) and which cover the entire screen area, and normal layers which are are 64 by 64 tiles (512×512 pixels). This mode can be set on a per layer basis in the `SCROLL_WIDE_MAP_ENABLE` register.


```
                      SCROLL_WIDE_MAP_ENABLE

 15  14  13  12  11  10   9   8   7   6   5   4   3   2   1   0
┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
│   │   │   │   │   │   │   │   │   │   │   │   │W3 │W2 │W1 │W0 │
└───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘

W3,W2,W1,W0: "wide map" mode for respective scroll layer
  0: 64×64 tiles (512×512 pixels) mode
  1: 128×64 tiles (1024×512 pixels) mode

```

Wide layers can be considered as normal layers laid out side to side horizontally, consecutive in memory. So tile offsets will be like this:

```
      wide layer

             x_tile
    0        63 64       127
  0 ┌──────────┬──────────┐
    │0         │4096      │
    │          │          │
    │          │          │
  y │    ..    │    ..    │
tile│          │          │
    │          │          │
    │      4095│      8191│
 63 └──────────┴──────────┘

```

Layers can be scrolled with pixel granularity through the `HSCROLL_X` and `VSCROLL_X` registers. These registers configure the starting coordinate visible at the top-left of the display. The layers wrap around at the edges, both horizontally and vertically. This means that when scrolling, when the edge of the layer comes into view, the other side of the layer will be visible:

```
┌──────┐           ┌┈┈┈┬┈┈┈┐
│A    B│           ┆   │   ┆
│      │  scroll   ╎  D│C  ┆
│      │  →     →  ├───┼───┤
│      │  offset   ┆  B│A  ┆
│C    D│           ┆   │   ┆
└──────┘           └┈┈┈┴┈┈┈┘

 layer             visible screen area
```

Note that there will always be part of a layer off-screen vertically. Increasing the scroll coordinate in any direction will keep scrolling indefinitely, as the layer dimension (as well as the range of the scroll register) is a power of two, and scrolling wraps around.

Layer maps and layer tiles graphics must be aligned in memory to an address that is a multiple of 4096 and 2048 respectively. These offsets are configured through the `SCROLL_TILE_ADDRESS_BASE` and `SCROLL_MAP_ADDRESS_BASE` registers respectively:

```
                       SCROLL_TILE_ADDRESS_BASE

 15  14  13  12  11  10   9   8   7   6   5   4   3   2   1   0
┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
│     SCTB3     │     SCTB2     │     SCTB1     │     SCTB0     │
└───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘

SCTB0..SCTB3: offsets of the tile address base from the start
  of VDP memory, in units of 2048 words.

tile_base[x] = SCTBx << 11
```

```
                       SCROLL_MAP_ADDRESS_BASE

 15  14  13  12  11  10   9   8   7   6   5   4   3   2   1   0
┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
│ - │   SCMB3   │ - │   SCMB2   │ - │   SCMB1   │ - │   SCMB0   │
└───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘

SCROLL0..SCROLL3: offsets of the map address base from the start of
  VDP memory, in units of 4096 words.

map_base[x] = SCMBx << 12
```

Sprites
-------

256 sprites can be active at the same time. Each sprite can be 8×8, 8×16, 16×8 or 16×16 pixels, individually.

All sprites are laid out in 8×8 tiles. Larger sprites will have consecutive tile ids for the columns, but rows are separated by an offset of 16. For example a 16×16 sprite has its four tile ids laid out like this:

```
    0     7 8    15
    ┌──────┬──────┐
    │ t+0  │ t+1  │
  7 │      │      │
    ├──────┼──────┤
  8 │ t+16 │ t+17 │
    │      │      │
 15 └──────┴──────┘
```

where `t` is the base id in the sprite metadata. 8×16, 16×8 sprites are similar: just leave out the bottom row or right column.

Each sprite is defined by three 16-bit words of sprite metadata, `x`, `y`, `g`, written sequentially to the `SPRITE_BLOCK_ADDRESS` register.

- `x` specifies the x position on the screen, as well as whether to flip the sprite in x direction:

```
                           sprite.x

 15  14  13  12  11  10   9   8   7   6   5   4   3   2   1   0
┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
│ - │ - │ - │ - │ - │XF │               XPOS                    │
└───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘

XPOS: x position of the sprite in screen coordinates
XF: x-flip bit
```

- `y` specifies the y position on the screen, as well as whether to flip the sprite in y direction. It also specifies the sprite dimensions.

```
                           sprite.y

 15  14  13  12  11  10   9   8   7   6   5   4   3   2   1   0
┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
│ - │ - │ - │ - │ W │ H │YF │             YPOS                  │
└───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘

YPOS: y position of the sprite in screen coordinates
YF: y-flip bit
W: sprite is 16 pixels instead of 8 pixels wide
H: sprite is 16 pixels instead of 8 pixels tall
```

- `g` defines the (base) tile id, which palette to use, and a rendering priority which specifies at which depth it will appear relative to layers.

```
                           sprite.g

 15  14  13  12  11  10   9   8   7   6   5   4   3   2   1   0
┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
│     PAL       │  PRI  │              TILEID                   │
└───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘

TILEID: base tile id
PRI: sprite priority; priority 0 sprites are behind layer 2, the hindmost layer,
     whereas priority 3 sprites are on top of layer 0
PAL: the palette to use for this sprite (upper 4 bits of palette index)
```

Sprite tile ids range from 0..1023, which means up to 1024 (8×8) or 256 (16×16) different sprite graphics can be available at the time to choose from. This is great for animations. It would however fill half of VDP RAM by itself! The base of the sprite tiles in VDP memory is configured through the `SPRITE_TILE_BASE` register:

```
                       SPRITE_TILE_BASE

 15  14  13  12  11  10   9   8   7   6   5   4   3   2   1   0
┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
│ - │ - │     SPTB      │ - │ - │ - │ - │ - │ - │ - │ - │ - │ - │
└───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘

SPTB: offset of sprite tile base from the start of VDP memory,
  in units of 2048 words.

sprite_tile_base[x] = SPTB << 11
```

The `XPOS` and `YPOS` specify where the top left corner of the sprite is rendered on the screen. Sprites can be partially visible at the borders of the screen. To have a sprite partially visible at the left and/or top of the screen, subtract from the maximum values; the coordinates wrap around.

The flip bits flip (mirror) the contents of the sprite horizontally and/or vertically. All sprites, even 8×8 ones, are flipped as if they were the full 16×16, so when changing orientation so it is necessary to add an offset to the position to compensate for that.

There is no separate visibility bit. To disable a sprite it is placed outside the view, generally at `y` equal to the screen height.

TODO: what is the priority order *between* sprites?

Affine layer
------------

The VDP supports one 1024×1024 pixel affine-transformable layer.

The affine layer is a 256 color image, so it can utilize the entire palette.

The data for the affine layer is always stored at offset `0` in memory. There, a 128×128 tile map and graphics for 256 different `8x8` 8-bit color tiles are interleaved.

Rendering of the affine layer is configured through the following registers:

- `AFFINE_PRETRANSLATE_X`, `AFFINE_PRETRANSLATE_Y`: Pre-transformation translation.
- `MATRIX_A`, `MATRIX_B`, `MATRIX_C`, `MATRIX_D`: Four-element 2D transformation matrix.
- `AFFINE_TRANSLATE_X`, `AFFINE_TRANSLATE_Y`: Final translation.

Use of the affine layer is demonstrated in the `affine_platformer` demo.

Copper
------

The VDP features a "copper" coprocessor to perform raster effects. This is a small CPU with four instructions that can modify the VDP registers on the fly, with high precision, *while* the image is being output to the display.

This allows for tricks where one region of the screen is differently configured from another. A common "copper" effect is to change the palette for every line to get access to more colors (see the `copper_bars` demo). However, much more is possible. For example, only either the affine layer or the normal scroll layers can be enabled at the same time. Using the copper, it's possible to enable one in one region of the screen and the other in another (see the `affine_platformer` and `copper_polygon` demos).

Copper instructions are 16 bits. It has four main instruction types:

```
op  name              description
--  ---------------- --------------------------------------------
0   SET_TARGET        Set target x or y position
1   WRITE_COMPRESSED  Write register (compressed representation)
2   WRITE_REG         Write registers
3   JUMP              Set instruction pointer
```

The two most significant bits of the copper instruction word are the opcode `OP`. The meaning of the rest of the bits depends on the this opcode.

```
                       copper_instruction

 15  14  13  12  11  10   9   8   7   6   5   4   3   2   1   0
┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
│  OP   │                     ... ARGS ...                      │
└───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘

General instruction format.

OP, ARGS: As specified per instruction below.


                          SET_TARGET

 15  14  13  12  11  10   9   8   7   6   5   4   3   2   1   0
┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
│ 0 │ 0 │ - │WT │ Y │               TGT                         │
└───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘

Sets either the x or y coordinate of the raster target, then
optionally waits until the current raster x and y match
the target.

TGT: raster x/y value to target
Y: coordinate selection
     0: select x
     1: select y
WT: wait bit
     0: don't wait, set target x or y register and immediately advance to next
        op
     1: set target x/y register then wait until raster x and y reach their
        target before advancing to next op


                       WRITE_COMPRESSED

 15  14  13  12  11  10   9   8   7   6   5   4   3   2   1   0
┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
│ 0 │ 1 │ - │ - │ITY│        DAT        │         REG           │
└───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘

Write a short value to a VDP register, compactly. This is useful
because effects are often limited by the size of the copper
RAM.

REG: target VDP register
DAT: data to write
ITY: autoincrement target Y (then automatically continue)


                           WRITE_REG

 15  14  13  12  11  10   9   8   7   6   5   4   3   2   1   0
┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
│ 1 │ 0 │ITY│  BAS  │         NB        │ - │        REG        │
└───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘

Extended write to register instruction.

REG: target base VDP register
NB: number of batches to write minus one
BAS: reg increment mode (batch size)
     0: REG+0, repeat
     1: REG+0, REG+1, repeat
     2: REG+0, REG+1, REG+2, REG+3, repeat
ITY: autoincrement target Y and wait between batches


                             JUMP

 15  14  13  12  11  10   9   8   7   6   5   4   3   2   1   0
┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
│ 1 │ 1 │ - │ - │ - │                    ADR                    │
└───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘

Unconditional jump.

ADR: jump target address (immediate)

```

When the copper is started (through writing `1` to VDP register `ENABLE_COPPER`) it starts executing instructions at address `0` in copper memory.

```
                        ENABLE_COPPER

 15  14  13  12  11  10   9   8   7   6   5   4   3   2   1   0
┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
│ - │ - │ - │ - │ - │ - │ - │ - │ - │ - │ - │ - │ - │ - │ - │EN │
└───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘

EN: 1=enable copper coprocessor, 0=disable copper coprocessor
  Resets the instruction pointer to 0 when going from disabled to enabled.
```

Waiting for the target raster position will always wait for both the x and y raster position to match. So when an operation (say, auto-increment) sets only the y coordinate, the old target position for x is retained.

The copper's VDP register writes may interfere with VDP register writes from the CPU. For example doing VRAM updates while the VDP writes a palette register can result in wrong values. It is recommended to disable the copper when accessing VDP registers or memory from the CPU, when the raster position is off-screen.

System status
=============

The system status peripheral exposes global status information and configuration for the system. Currently there is only one function: setting the LEDs on the board. This is often useful as a debug output.

There is one 32-bit register.

```
reg    r/w bits     name        description
------ --- -------  ----------  ----------------------------------------
0x0000  w  [7:0]    LED         LED status
```

DSP
===

The DSP (also `SYS_MUL`) has one function: a signed `s16 × s16 = s32` multiply. It exposes a hardware multiplier from the FPGA fabric to code running on the CPU. This allows for fast multiplication when necessary, even though the CPU architecture itself has no multiplication instruction.

```
reg    r/w bits     name        description
------ --- -------  ----------  ----------------------------------------
0x0000  w  [15:0]   MUL_A       Multiplication operand A
0x0004  w  [15:0]   MUL_B       Multiplication operand B
0x0000  r  [31:0]   MUL_RESULT  Multiplication result
```

After writing to `MUL_A` and `MUL_B`, `MUL_RESULT` will read as the signed 32-bit result of `MUL_A * MUL_B`. The result in available instantly from the point of view of the CPU.

Gamepad
=======

The gamepad peripheral exposes a bit-banging serial interface to read out SNES (or emulated SNES) gamepads.

There is one 32-bit register, of which the function differs for read or write.

```
reg    r/w bits     name        description
------ --- -------  ----------  ----------------------------------------
0x0000  w  [0:0]    LATCH       Latch the current state of pad inputs
0x0000  w  [1:1]    CLK         Serial clock out
0x0000  r  [0:0]    P1          Player 1 input
0x0000  r  [1:1]    P2          Player 2 input
```

Using the following pseudo-code

```
p1 := 0
p2 := 0
LATCH := 1
LATCH := 0
for bit in 0..15
    tmp := {P2,P1}
    PAD_CLK := 1
    PAD_CLK := 0
    p1[bit] := tmp.P1
    p2[bit] := tmp.P2
```

16 bits can be clocked out on `P1` and `P2` (LSB to MSB), of which the bottom 12 have a defined bit value:

```
                           gamepad_in

 15  14  13  12  11  10   9   8   7   6   5   4   3   2   1   0
┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
│ - │ - │ - │ - │ R │ L │ X │ A │RT │LT │DN │UP │ST │SE │ Y │ B │
└───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘

B: "B" button state
Y: "Y" button state
SE: "SELECT" button state
ST: "START" button state
UP: D-pad Up state
DN: D-pad Down state
LT: D-pad Left state
RT: D-pad Right state
A: "A" button state
X: "X" button state
L: Left shoulder button state
R: Right shoulder button state
```

A bit will be `1` while the associated button is pressed, and `0` when not. Edge sensitivity is implemented manually in the library.

VDP "copper" RAM
================

The [VDP "copper" coprocessor](#copper) has its own memory-mapped RAM of 4 kB where the instructions for the coprocessor are stored. It is write-only from the CPU point of view and read-only from the copper. This memory is addressed in 16-bit words.

Bootloader ROM
==============

There is 1 kB (iCE40) or 2 kB (ECP5) of bootloader ROM integrated in the design. This is the first code that is invoked when the system starts. It is (mostly) assembly code, and is compiled from the `firmware` directory. It clears the registers to an initial state, sets up the flash chip, copies the first 64 kB of flash to RAM then jumps to RAM at offset `0x0000_0000`.

Flash control
=============

The flash control register can be used to communicate with the SPI flash, or configure hardware flash access, allowing the CPU to access flash as if it was directly wired into the address space (see [Flash access](#flash-access)). This setup is generally done by the bootloader, and not touched afterwards. However for special cases it could be used in application code, for example to write to flash to store savegames.

```
reg    r/w bits     name        description
------ --- -------  ----------  --------------------------
0x0000  r  [3:0]    OUT         SPI output pins
0x0000  w  [3:0]    IN          SPI input pins
0x0000  w  [7:4]    IN_EN       Input/output mode select
0x0000  w  [8:8]    CLK         SPI clock
0x0000  w  [9:9]    CSN         SPI chip select (negated)
0x0000  w  [15:15]  ACTIVE      Enable flash controller
```

Audio
=====

The audio peripheral of the Icestation-32 streams digital audio directly from flash (there is no way sampled audio fits in the limited RAM), and can mix up to 8 channels. There is separate stereo volume and pitch control for each channel.

A single audio data format is supported: mono IMA-ADPCM\* 44100Hz. The ADPCM block size is fixed at 1024 bytes.

Use of the audio peripheral is demonstrated in the `audio_drumkit` demo.

Conversion
----------

To convert audio to the required ADPCM format without a WAV header there's a special ADPCM converter tool (adpcm-xq), of which the source code is in `super-miyamoto-sprint/utility/adpcm-xq` as well as [its own repository](https://github.com/dbry/adpcm-xq).

    ADPCM-XQ   Xtreme Quality IMA-ADPCM WAV Encoder / Decoder   Version 0.3
    Copyright (c) 2018 David Bryant. All Rights Reserved.

The command line to convert any audio file to the required format:

    sox <file_in.mp3/wav/flac> -b16 -r44100 -c1 <wav16_file>
    adpcm-xq -r -y <wav16_file> <adpcm_file>

Alternatively, ffmpeg can be used:

    ffmpeg -y -guess_layout_max 0 -i $^ -f s16le -acodec adpcm_ima_wav -ac 1

\* ADPCM = "Adaptive Differential Pulse-Code Modulation". See [here](https://wiki.multimedia.cx/index.php/IMA_ADPCM) for a more in-detail description of the encoding. A scanned and OCRed version of the original specification [can be found here](http://www.cs.columbia.edu/~hgs/audio/dvi/IMA_ADPCM.pdf).

Registers
---------

The memory-mapped audio registers are laid out as follows. The registers must be addressed as 32-bit except for the channel descriptors.

```
reg    r/w bits     name        description
------ --- -------  ----------  ------------------------------------------------
0x0000  w  -        CHANNELS    Audio channel descriptors (16 bytes per channel)
0x0200  w  [7:0]    PLAY        Start playing (bit per channel)
0x0200  r  [7:0]    PLAYING     Playing status (bit per channel)
0x0204  w  [7:0]    STOP        Stop playing (bit per channel)
0x0204  r  [7:0]    ENDED       Sample ended (bit per channel)
0x0208  r  [0:0]    BUSY        Audio busy status
```

- Write a `1` bit to the `PLAY` register at a given bit position to start playing the sample in that channel. Writing `0` will have no effect. If the sample was already playing it will restart.
- Write a `1` bit to the `STOP` register at a given bit position to stop playing the sample in that channel immediately. Writing `0`, or `1` if no sample was playing will have no effect.

Channel descriptors are a byte-addressable 16-byte structure that specifies the sample to play on a channel:
```
ofs   type     name             description
----  ----     --------------   -------------------------------
0x00  u16      START_ADDRESS    Sample starting address
0x02  u8       (padding)
0x03  u8       FLAGS            bit 0: LOOP
0x04  u16      END_ADDRESS      Sample stop address
0x06  u16      LOOP_ADDRESS     Sample loop address
0x08  u8       VOLUME_LEFT      Left sound volume
0x09  u8       VOLUME_RIGHT     Right sound volume
0x0a  u16      PITCH            Sound pitch
0x0c  u16      (padding)
0x0e  u16      (padding)
```

- The sample start, end and loop address specify from which address (relative to the start address of the program in flash) the sample is played, and where (if enabled) where to restart after loop. The addresses are specified in a multiple of the ADPCM block size, 1024 bytes.

- The sound `VOLUME` can be specified separately for left and right for stereo positioning effects. Volumes are a value between `0` (no sound) and `255` (loudest). At the loudest volumes there can be clipping, values around 16 are safest.

- A `PITCH` value of `0x1000` plays the sound at the original pitch. A higher value of `PITCH` plays the sound at a higher playback rate, thus a higher pitch. So a value of `0x2000` would double the pitch, and a value of `0x800` half it.

Flash access
============

When it is configured correctly by the boot ROM, the SPI flash is directly accessible from the CPU, starting at address `0x1000000`.

Arbitrary data reads from this area are possible. The addressed area starts at the beginning of the program in flash, because the bootloader will have read the first 64 kB starting from `0x1000000` into RAM at boot. If a game has resources that won't fit in the limited RAM, they can be stored after the initial 64 kB where they can be read through this memory address region.
