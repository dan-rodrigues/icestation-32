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
    // this needs to be adjusted based on how many available layers there are
    // INTERLEAVED_LAYER_COUNT = 4 etc.
    const uint8_t layer_count = 4;
    const uint16_t x_base = 500;
    const uint16_t y_base = 240;

    uint8_t enabled_layers = SCROLL0 | SCROLL1 | SCROLL2 | (layer_count == 4 ? SCROLL3 : 0);

    vdp_enable_layers(enabled_layers);
    vdp_set_wide_map_layers(0); // !
    vdp_set_alpha_over_layers(0);

    const uint16_t tile_vram_base = 0x0000;

    const uint16_t map_vram_base = 0x1000;
    const uint16_t map_size = 0x2000; // this size might be confusing due to (0x1000 words * 2) for interleaving

    for (uint8_t i = 0; i < layer_count; i++) {
        uint16_t layer_map_base = i / 2 * map_size + map_vram_base;
        vdp_set_layer_map_base(i, layer_map_base);
        vdp_set_layer_tile_base(i, tile_vram_base);
    }

    vdp_set_vram_increment(1);
    vdp_seek_vram(0x0000);
    vdp_fill_vram(0x8000, ' ');

    upload_font(tile_vram_base);

    const uint16_t bg_color = 0xf033;
    static const uint16_t fg_colors[] = {0xffff, 0xfff0, 0xf0ff, 0xf0f0};

    // workaround interleaving for now, just write same char twice to odd / even words
    vdp_set_single_palette_color(0, bg_color);

    for (uint8_t i = 0; i < layer_count; i++) {
        vdp_set_single_palette_color(i * 0x10 + 1, fg_colors[i]);
    }

    const char *const hello_string = "Hello world!";
    const uint8_t flip_x = false;
    const uint8_t flip_y = false;

    for (uint8_t i = 0; i < layer_count; i++) {
        uint16_t layer_map_base = (i / 2) * map_size + map_vram_base;
        vdp_seek_vram(layer_map_base + (i & 1));
        vdp_set_vram_increment(2);

        uint8_t palette_id = i;

        const char *string = hello_string;

        while (*string) {
            uint16_t map = *string & 0xff;
            map |= palette_id << SCROLL_MAP_PAL_SHIFT;
            map |= flip_x << SCROLL_MAP_X_FLIP_SHIFT;
            map |= flip_y << SCROLL_MAP_Y_FLIP_SHIFT;

            vdp_write_vram(map);

            string++;
        }
    }

    uint32_t frame_counter = 0;

    while (true) {
        for (uint8_t i = 0; i < layer_count; i++) {
            uint16_t scroll = frame_counter / (i + 1);
            uint16_t layer_ofset = i * 32;
            vdp_set_layer_scroll(i, -x_base + layer_ofset + scroll, -y_base + layer_ofset + scroll);
        }

        vdp_wait_frame_ended();

        frame_counter++;
    }
}
