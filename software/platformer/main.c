// main.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include "vdp.h"
#include "math_util.h"

#include <stdint.h>
#include <stdbool.h>

#include "fg_tiles.h"
#include "fg_palette.h"

// TODO rename and convert from bin
#include "map-flat.h"

int main() {
    vdp_enable_layers(SCROLL0);
    vdp_set_wide_map_layers(SCROLL0);
    vdp_set_alpha_over_layers(0);

    vdp_set_layer_scroll(0, 0, 0);

    const uint16_t tile_vram_base = 0x0000;

    // foreground tiles
    // the map expects them on the latter pages so
    const uint16_t foreground_tile_count = 128;

    vdp_set_layer_tile_base(0, tile_vram_base);

    vdp_set_vram_increment(1);
    vdp_seek_vram(0 + 0x1800);
    for (uint16_t i = 0; i < foreground_tile_count * 32 / 4; i++) {
        vdp_write_vram(tiles[i] & 0xffff);
        vdp_write_vram(tiles[i] >> 16);
    }

    // foreground map

    const uint16_t map_vram_base = 0x4000;

    vdp_set_layer_map_base(0, map_vram_base);

    vdp_set_vram_increment(2);
    vdp_seek_vram(map_vram_base);

    uint32_t *map = (uint32_t *)mapFlat;
    for (uint16_t i = 0; i < 0x2000 / 4; i++) {
        vdp_write_vram(map[i] & 0xffff);
        vdp_write_vram(map[i] >> 16);
    }

    vdp_set_vram_increment(1);

    // ...

    // foreground palette

    vdp_write_palette_range(2 * 0x10, 0x10, palette);

    while (1) {
        vdp_wait_frame_ended();
    }

    return 0;
}
