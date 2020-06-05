// main.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#include "vdp.h"
#include "vdp_regs.h"
#include "copper.h"
#include "math_util.h"

static const uint16_t TILE_BASE = 0x0000;
static const uint16_t MAP_BASE = 0x1000;

static const uint8_t BAR_PALETTE_ID = 0;
static const uint8_t BAR_COLOR_ID = 1;

static void draw_raster_bars(uint16_t line_offset, uint16_t angle);

int main() {
    vdp_enable_copper(false);
    vdp_enable_layers(SCROLL0 | SCROLL1);
    vdp_set_alpha_over_layers(SCROLL0);
    vdp_set_wide_map_layers(0);

    // one opaque tile to use for all graphics in demo

    const uint16_t opaque_tile = 0;

    vdp_set_layer_tile_base(0, TILE_BASE);
    vdp_set_layer_tile_base(1, TILE_BASE);

    vdp_seek_vram(TILE_BASE);
    vdp_set_vram_increment(1);
    vdp_fill_vram(0x10, 0x1111);

    // checkerboard background (512x512, tiled repeatedly)

    vdp_set_layer_map_base(1, MAP_BASE);
    vdp_seek_vram(MAP_BASE + 1);
    vdp_set_vram_increment(2);

    const uint8_t checkerboard_dimension = 4;

    for (uint8_t y = 0; y < 64; y++) {
        uint8_t y_even = (y / checkerboard_dimension) & 1;

        for (uint8_t x = 0; x < 64; x++) {
            const uint8_t light_palette = 1;
            const uint8_t dark_palette = 2;

            uint8_t x_even = (x / checkerboard_dimension) & 1;
            bool is_dark = y_even ^ x_even;

            uint8_t palette = is_dark ? dark_palette : light_palette;
            uint16_t map_word = opaque_tile | palette << SCROLL_MAP_PAL_SHIFT;
            vdp_write_vram(map_word);
        }
    }

    vdp_set_layer_scroll(1, 0, 0);

    // initialize all map tiles to the empty opaque tile (space character)

    vdp_set_layer_map_base(0, MAP_BASE);
    vdp_set_vram_increment(2);
    vdp_seek_vram(MAP_BASE + 0);
    vdp_fill_vram(0x2000, opaque_tile | BAR_PALETTE_ID << SCROLL_MAP_PAL_SHIFT);

    // checkerboard background palette

    const uint8_t checkerboard_bright_palette_id = 0x11;
    const uint16_t checkerboard_bright_color = 0xfaaa;
    vdp_set_single_palette_color(checkerboard_bright_palette_id, checkerboard_bright_color);

    const uint8_t checkerboard_dark_palette_id = 0x21;
    const uint16_t checkerboard_dark_color = 0xf000;
    vdp_set_single_palette_color(checkerboard_dark_palette_id, checkerboard_dark_color);

    uint16_t line_offset = 0;
    uint16_t angle = 0;

    vdp_wait_frame_ended();

    while (true) {
        draw_raster_bars(line_offset, angle);

        vdp_wait_frame_ended();
        vdp_enable_copper(false);

        line_offset++;
        angle++;
    }

    return 0;
}

static void draw_raster_bars(uint16_t line_offset, uint16_t angle) {
    static const uint16_t color_masks[] = {
        0xff00, 0xf0f0, 0xf00f, 0xffff, 0xfff0, 0xf0ff, 0xff0f, 0xffff
    };
    const size_t color_mask_count = sizeof(color_masks) / sizeof(uint16_t);
    const uint8_t bar_height = 32;

    COPBatchWriteConfig config = {
        .mode = CWM_DOUBLE,
        .reg = &VDP_PALETTE_ADDRESS,
        .batch_wait_between_lines = true
    };

    cop_ram_seek(0);

    cop_set_target_x(0);
    cop_wait_target_y(0);
    cop_wait_target_x(2);

    vdp_enable_copper(true);

    uint16_t line = 0;

    while (line < SCREEN_ACTIVE_HEIGHT) {
        const uint16_t angle_delta = 6;
        const int16_t offset_scale = 0x18;

        int16_t sint = sin(angle);
        angle += angle_delta;
        int16_t offset = sys_multiply(sint, offset_scale) / SIN_MAX;

        uint16_t selected_line = line + line_offset + offset;
        uint16_t bar_offset = selected_line % bar_height;

        config.batch_count = 1;
        cop_start_batch_write(&config);

        uint8_t mask_selected = (selected_line / bar_height) % color_mask_count;
        uint16_t color_mask = color_masks[mask_selected];

        uint16_t color = 0;
        uint8_t y = bar_offset % (bar_height / 2);

        if (bar_offset < (bar_height / 2)) {
            uint8_t alpha = y;
            color = alpha << 12 | y << 8 | y << 4 | y;
            color &= color_mask;
        } else {
            uint8_t alpha = ~y & 0xf;
            color = (0x0fff | alpha << 12) - (y << 8) - (y << 4) - y;
            color &= color_mask;
        }

        cop_add_batch_double(&config, BAR_COLOR_ID, color);

        line++;
        cop_wait_target_y(line);
    }

    cop_jump(0);
}
