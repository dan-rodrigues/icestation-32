// main.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#include "assert.h"
#include "vdp.h"
#include "font.h"
#include "gamepad.h"
#include "vdp_print.h"

static const uint8_t TEXT_PALETTE_ID = 0;
static const uint16_t MAP_VRAM_BASE = 0x4000;
static const uint16_t TILE_VRAM_BASE = 0x0000;

static void print_gamepad(uint16_t pad_encoded, uint16_t base_x, uint16_t base_y);

int main() {
    vdp_enable_layers(SCROLL0);
    vdp_set_wide_map_layers(SCROLL0);
    vdp_set_alpha_over_layers(0);

    vp_print_init();

    vdp_set_vram_increment(1);

    vdp_set_layer_scroll(0, 0, 0);

    vdp_seek_vram(0x0000);
    vdp_fill_vram(0x8000, ' ');

    const uint16_t tile_vram_base = 0x0000;
    const uint16_t map_vram_base = 0x4000;

    vdp_set_layer_tile_base(0, TILE_VRAM_BASE);
    upload_font(tile_vram_base);

    const uint16_t bg_color = 0xf033;
    const uint16_t fg_color = 0xffff;

    vdp_set_single_palette_color(TEXT_PALETTE_ID * 0x10 + 0, bg_color);
    vdp_set_single_palette_color(TEXT_PALETTE_ID * 0x10 + 1, fg_color);

    vdp_set_layer_map_base(0, MAP_VRAM_BASE);
    vdp_seek_vram(map_vram_base);

    uint16_t p1_current = 0, p2_current = 0;

    const uint8_t p1_base_x = 40;
    const uint8_t p1_base_y = 10;

    const uint8_t p2_base_x = 60;
    const uint8_t p2_base_y = 10;

    while (true) {
        vdp_wait_frame_ended();

        pad_read(&p1_current, &p2_current, NULL, NULL);

        vp_printf(p1_base_x, p1_base_y, TEXT_PALETTE_ID, SCROLL0, MAP_VRAM_BASE, "Player 1");
        print_gamepad(p1_current, p1_base_x, p1_base_y + 2);

        vp_printf(p2_base_x, p2_base_y, TEXT_PALETTE_ID, SCROLL0, MAP_VRAM_BASE, "Player 2");
        print_gamepad(p2_current, p2_base_x, p2_base_y + 2);
    }
}

static void print_gamepad(uint16_t pad_encoded, uint16_t base_x, uint16_t base_y) {
    static const char * const input_labels[] = {
        "B", "Y", "Select", "Start",
        "Up", "Down", "Left", "Right",
        "A", "X", "L", "R"
    };

    for (uint8_t i = 0; i < 12; i++) {
        const uint8_t spacing = 8;

        vp_printf(base_x, base_y + i,
                  TEXT_PALETTE_ID, SCROLL0, MAP_VRAM_BASE,
                  "%s:",
                  input_labels[i]);

        vp_printf(base_x + spacing, base_y + i,
                  TEXT_PALETTE_ID, SCROLL0, MAP_VRAM_BASE,
                  "%d",
                  (pad_encoded >> i) & 1);
    }
}
