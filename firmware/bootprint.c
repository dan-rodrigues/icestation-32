// bootprint.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include "bootprint.h"

#include "font.h"
#include "vdp.h"
#include "vdp_regs.h"

void bp_print_init() {
    vdp_enable_layers(SCROLL0);
    vdp_set_wide_map_layers(SCROLL0);
    vdp_set_alpha_over_layers(0);
    vdp_set_vram_increment(1);

    vdp_seek_vram(0x0000);
    vdp_fill_vram(0x8000, 0);

    // Monochrome minimal font

    const uint16_t tile_vram_base = 0x0000;
    const uint16_t map_vram_base = 0x2000;

    // The C library functions for this is large and unnecessary for this minimal use case
    VDP_SCROLL_TILE_ADDRESS_BASE = 0;
    VDP_SCROLL_MAP_ADDRESS_BASE = (map_vram_base >> 12 &0xf);

    // Monochrome palette

    const uint16_t bg_color = 0xf033;
    const uint16_t fg_color = 0xffff;

    vdp_set_single_palette_color(0, bg_color);
    vdp_set_single_palette_color(1, fg_color);

    // + 0x10 to skip the space character
    upload_font_minimal(tile_vram_base + 0x10);
}

void bp_print(uint16_t vram_start, const char *string) {
    vdp_seek_vram(vram_start);

    while (*string) {
        // Map to the minimal character set
        // This could alternatively be preencoded in the caller to avoid doing this here
        uint8_t ascii_char = *string;
        if (ascii_char == ' ') {
            ascii_char = 0;
        } else if (ascii_char > '9') {
            ascii_char -= 0x40;
        }

        uint16_t map = ascii_char;

        vdp_write_vram(map);

        string++;
    }
}

// TODO: stuff for board greetings

void bp_print_greetings(void) {
    // other palettes...
    vdp_set_single_palette_color(0x11, 0xfff0);
    vdp_set_single_palette_color(0x21, 0xf0ff);
    vdp_set_single_palette_color(0x31, 0xff0f);

    const char *greeting = "ULX3S SAYS HELLO";

    for (uint8_t y = 0; y < 64; y++) {
        uint16_t vram_start = 0x2000 + y * 0x40 + y;

        // repetitions?
        for (uint8_t x = 0; x < 10; x++) {
            bp_print(vram_start, greeting);
            vram_start += 20;
        }
    }
}
