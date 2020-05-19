// main.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include <stdint.h>
#include <stdbool.h>

#include "vdp.h"
#include "font.h"

int main() {
    vdp_enable_layers(SCROLL0);
    vdp_set_wide_map_layers(SCROLL0);
    vdp_set_alpha_over_layers(0);

    vdp_set_layer_scroll(0, 0, 0);

    vdp_set_vram_increment(1);
    vdp_seek_vram(0x0000);
    vdp_fill_vram(0x8000, ' ');

    const uint16_t tile_vram_base = 0x0000;
    const uint16_t map_vram_base = 0x4000;

    vdp_set_layer_tile_base(0, tile_vram_base);
    upload_font(tile_vram_base);

    const uint16_t bg_color = 0xf033;
    const uint16_t fg_color = 0xffff;

    vdp_set_single_palette_color(0, bg_color);
    vdp_set_single_palette_color(1, fg_color);

    vdp_set_layer_map_base(0, map_vram_base);
    vdp_seek_vram(map_vram_base);
    vdp_set_vram_increment(2);

    const char *const hello_string = "Hello world!";
    const uint8_t palette_id = 0x0;
    const uint8_t flip_x = false;
    const uint8_t flip_y = false;

    const char *string = hello_string;

    while (*string) {
        uint16_t map = *string & 0xff;
        map |= palette_id << SCROLL_MAP_PAL_SHIFT;
        map |= flip_x << SCROLL_MAP_X_FLIP_SHIFT;
        map |= flip_y << SCROLL_MAP_Y_FLIP_SHIFT;

        vdp_write_vram(map);

        string++;
    }

    while (true) {}
}
